import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading.dart';
import '../auth/providers/auth_providers.dart';
import '../players/domain/player.dart';
import '../players/providers/players_providers.dart';
import '../seasons/providers/seasons_providers.dart';
import 'domain/game_play.dart';
import 'domain/game_roster_resolution.dart';
import 'providers/game_plays_provider.dart';
import 'providers/games_providers.dart';

class GameCapturePage extends ConsumerStatefulWidget {
  const GameCapturePage({
    super.key,
    required this.gameId,
  });

  final String gameId;

  @override
  ConsumerState<GameCapturePage> createState() => _GameCapturePageState();
}

class _GameCapturePageState extends ConsumerState<GameCapturePage> {
  int _half = 1;
  String _unit = 'ofensiva';

  @override
  Widget build(BuildContext context) {
    final gameAsync = ref.watch(gameByIdProvider(widget.gameId));
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Partido - Captura')),
      body: gameAsync.when(
        data: (game) {
          if (game == null) {
            return const EmptyState(
              title: 'Partido no encontrado',
              message: 'No se encontró el partido.',
              icon: Icons.sports_football_outlined,
            );
          }

          final activeSeasonId = ref.watch(activeSeasonIdProvider);
          final rosterSeasonId = resolveRosterSeasonIdForCapture(
            game,
            activeSeasonId: activeSeasonId,
          );
          if (rosterSeasonId == null) {
            return const EmptyState(
              title: 'Sin roster asignado',
              message: 'No hay roster asignado a este partido.',
              icon: Icons.groups_outlined,
            );
          }

          return profileAsync.when(
            data: (profile) {
              if (!(profile?.canWriteGeneral ?? false)) {
                return const EmptyState(
                  title: 'No tienes permisos para ver jugadas',
                  message: 'Solicita acceso de coach o super_admin.',
                  icon: Icons.lock_outline,
                );
              }

              final playersAsync =
                  ref.watch(playersBySeasonProvider(rosterSeasonId));
              final playsAsync =
                  ref.watch(gamePlaybookControllerProvider(widget.gameId));
              final canWrite = profile?.canWriteGeneral ?? false;
              return playersAsync.when(
                data: (playersRaw) {
                  final players = playersRaw.where((p) => p.isActive).toList()
                    ..sort((a, b) => a.jerseyNumber.compareTo(b.jerseyNumber));
                  return playsAsync.when(
                    data: (plays) {
                      final filtered = plays
                          .where((p) => p.half == _half && p.unit == _unit)
                          .toList();
                      final stats = buildGamePlayStats(plays);
                      return Column(
                        children: [
                          _Header(
                              game: game.opponent,
                              score: '${game.ourScore} - ${game.oppScore}'),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: SegmentedButton<int>(
                              segments: const [
                                ButtonSegment(
                                    value: 1, label: Text('Primer tiempo')),
                                ButtonSegment(
                                    value: 2, label: Text('Segundo tiempo')),
                              ],
                              selected: <int>{_half},
                              onSelectionChanged: (values) =>
                                  setState(() => _half = values.first),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SegmentedButton<String>(
                                    segments: const [
                                      ButtonSegment(
                                          value: 'ofensiva',
                                          label: Text('Ofensiva')),
                                      ButtonSegment(
                                          value: 'defensiva',
                                          label: Text('Defensiva')),
                                    ],
                                    selected: <String>{_unit},
                                    onSelectionChanged: (values) =>
                                        setState(() => _unit = values.first),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.icon(
                                  onPressed: canWrite
                                      ? () => _openNewPlaySheet(
                                            context,
                                            players: players,
                                            gameId: widget.gameId,
                                          )
                                      : null,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Nueva jugada'),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              children: [
                                Text(
                                  'Jugada por jugada (${filtered.length})',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                if (filtered.isEmpty)
                                  const EmptyState(
                                    title: 'Sin jugadas',
                                    message:
                                        'Aún no hay jugadas para esta vista.',
                                    icon: Icons.playlist_add_check_outlined,
                                  )
                                else
                                  ...List.generate(filtered.length, (i) {
                                    final play = filtered[i];
                                    return Card(
                                      child: ListTile(
                                        title: Text(
                                          '${i + 1}. ${unitLabel(play.unit)} • ${halfLabel(play.half)} • Yds ${play.yards}',
                                        ),
                                        subtitle: Text(_playSubtitle(play)),
                                        trailing: canWrite
                                            ? IconButton(
                                                icon: const Icon(
                                                    Icons.delete_outline),
                                                onPressed: play.id == null
                                                    ? null
                                                    : () async {
                                                        await ref
                                                            .read(
                                                              gamePlaybookControllerProvider(
                                                                      widget
                                                                          .gameId)
                                                                  .notifier,
                                                            )
                                                            .deletePlay(
                                                                play.id!);
                                                      },
                                              )
                                            : null,
                                      ),
                                    );
                                  }),
                                const SizedBox(height: 16),
                                Text(
                                  'Estadísticas',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 6),
                                _StatsCard(
                                  title: 'QB completados / intentos',
                                  values: _mergeTwo(
                                      stats.qbCompletions, stats.qbAttempts,
                                      separator: '/'),
                                ),
                                _StatsCard(
                                  title: 'Recepciones / Targets / Drops',
                                  values: _mergeThree(
                                    stats.receptions,
                                    stats.targets,
                                    stats.drops,
                                    separator: '/',
                                  ),
                                ),
                                _StatsCard(
                                  title: 'Yardas por recepción',
                                  values: stats.receivingYards,
                                ),
                                _StatsCard(
                                  title: 'Intercepciones (def)',
                                  values: stats.defInterceptions,
                                ),
                                _StatsCard(
                                  title: 'Tackle/Flag (def)',
                                  values: stats.tackleFlags,
                                ),
                                _StatsCard(
                                  title: 'Sacks (def)',
                                  values: stats.sacks,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () =>
                        const Loading(message: 'Cargando jugadas...'),
                    error: (error, _) => Center(child: Text('Error: $error')),
                  );
                },
                loading: () => const Loading(message: 'Cargando jugadores...'),
                error: (error, _) => Center(child: Text('Error: $error')),
              );
            },
            loading: () => const Loading(message: 'Cargando permisos...'),
            error: (error, _) => Center(child: Text('Error: $error')),
          );
        },
        loading: () => const Loading(message: 'Cargando partido...'),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Future<void> _openNewPlaySheet(
    BuildContext context, {
    required List<Player> players,
    required String gameId,
  }) async {
    final result = await showModalBottomSheet<_PlayDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _NewPlaySheet(
          players: players, gameId: gameId, initialUnit: _unit, half: _half),
    );
    if (result == null) return;

    try {
      await ref
          .read(gamePlaybookControllerProvider(widget.gameId).notifier)
          .addPlay(
            play: result.play,
            pointsForOur: result.pointsForOur,
          );
    } on PostgrestException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Map<String, int> _mergeTwo(Map<String, int> a, Map<String, int> b,
      {required String separator}) {
    final keys = <String>{...a.keys, ...b.keys};
    final out = <String, int>{};
    for (final key in keys) {
      out['$key (${a[key] ?? 0}$separator${b[key] ?? 0})'] = a[key] ?? 0;
    }
    return out;
  }

  Map<String, int> _mergeThree(
    Map<String, int> a,
    Map<String, int> b,
    Map<String, int> c, {
    required String separator,
  }) {
    final keys = <String>{...a.keys, ...b.keys, ...c.keys};
    final out = <String, int>{};
    for (final key in keys) {
      out['$key (${a[key] ?? 0}$separator${b[key] ?? 0}$separator${c[key] ?? 0})'] =
          a[key] ?? 0;
    }
    return out;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.game, required this.score});

  final String game;
  final String score;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ListTile(
        leading: const Icon(Icons.sports_football_outlined),
        title: Text('vs $game'),
        subtitle: const Text('Marcador actual'),
        trailing: Text(score, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.title, required this.values});

  final String title;
  final Map<String, int> values;

  @override
  Widget build(BuildContext context) {
    final sorted = values.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            if (sorted.isEmpty)
              const Text('Sin datos')
            else
              ...sorted.take(5).map((e) => Text('${e.key}: ${e.value}')),
          ],
        ),
      ),
    );
  }
}

class _PlayDraft {
  const _PlayDraft({
    required this.play,
    required this.pointsForOur,
  });

  final GamePlay play;
  final bool pointsForOur;
}

class _NewPlaySheet extends StatefulWidget {
  const _NewPlaySheet({
    required this.players,
    required this.gameId,
    required this.initialUnit,
    required this.half,
  });

  final List<Player> players;
  final String gameId;
  final String initialUnit;
  final int half;

  @override
  State<_NewPlaySheet> createState() => _NewPlaySheetState();
}

class _NewPlaySheetState extends State<_NewPlaySheet> {
  final _formKey = GlobalKey<FormState>();
  final _yardsController = TextEditingController(text: '0');
  final _distanceController = TextEditingController(text: '10');
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();
  final _penaltyController = TextEditingController();

  late String _unit;
  late int _half;
  bool _isPass = true;
  bool _isTarget = false;
  bool _isCompletion = false;
  bool _isDrop = false;
  bool _isPassTd = false;
  bool _isRush = false;
  bool _isRushTd = false;

  bool _isSack = false;
  bool _isTackleFlag = false;
  bool _isInterception = false;
  bool _isPick6 = false;
  bool _isPassDefended = false;
  bool _isPenalty = false;

  int _points = 0;
  bool _pointsForOur = true;
  int _down = 1;
  String? _qbId;
  String? _receiverId;
  String? _defenderId;

  @override
  void initState() {
    super.initState();
    _unit = widget.initialUnit;
    _half = widget.half;
  }

  @override
  void dispose() {
    _yardsController.dispose();
    _distanceController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    _penaltyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + inset),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Nueva jugada',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 1, label: Text('1er tiempo')),
                          ButtonSegment(value: 2, label: Text('2do tiempo')),
                        ],
                        selected: <int>{_half},
                        onSelectionChanged: (value) =>
                            setState(() => _half = value.first),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                              value: 'ofensiva', label: Text('Ofensiva')),
                          ButtonSegment(
                              value: 'defensiva', label: Text('Defensiva')),
                        ],
                        selected: <String>{_unit},
                        onSelectionChanged: (value) =>
                            setState(() => _unit = value.first),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_unit == 'ofensiva') _buildOffenseForm(),
                if (_unit == 'defensiva') _buildDefenseForm(),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _yardsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Yardas (permitido negativo)'),
                  validator: (value) =>
                      int.tryParse((value ?? '').trim()) == null
                          ? 'Número inválido'
                          : null,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: _points,
                  items: kPlayPointsOptions
                      .map((p) => DropdownMenuItem<int>(
                          value: p, child: Text(p.toString())))
                      .toList(),
                  onChanged: (value) => setState(() => _points = value ?? 0),
                  decoration:
                      const InputDecoration(labelText: 'Puntos de la jugada'),
                ),
                if (_points > 0) ...[
                  const SizedBox(height: 8),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                          value: true, label: Text('Puntos para nosotros')),
                      ButtonSegment(
                          value: false, label: Text('Puntos para rival')),
                    ],
                    selected: <bool>{_pointsForOur},
                    onSelectionChanged: (value) =>
                        setState(() => _pointsForOur = value.first),
                  ),
                ],
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                      labelText: 'Descripción (texto libre)'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'Notas'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submit,
                    child: const Text('Guardar jugada'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOffenseForm() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: _qbId,
          items: widget.players
              .map((p) => DropdownMenuItem(
                  value: p.id, child: Text('#${p.jerseyNumber} ${p.fullName}')))
              .toList(),
          onChanged: (value) => setState(() => _qbId = value),
          decoration: const InputDecoration(labelText: 'QB'),
          validator: (value) =>
              (value == null || value.trim().isEmpty) ? 'QB requerido' : null,
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Fue pase'),
          value: _isPass,
          onChanged: (v) => setState(() {
            _isPass = v;
            if (!v) {
              _isTarget = false;
              _isCompletion = false;
              _isDrop = false;
              _receiverId = null;
            }
          }),
        ),
        if (_isPass) ...[
          DropdownButtonFormField<String>(
            initialValue: _receiverId,
            items: widget.players
                .map((p) => DropdownMenuItem(
                    value: p.id,
                    child: Text('#${p.jerseyNumber} ${p.fullName}')))
                .toList(),
            onChanged: (value) => setState(() => _receiverId = value),
            decoration: const InputDecoration(labelText: 'Receptor'),
            validator: (value) {
              if (!_isTarget) return null;
              return (value == null || value.trim().isEmpty)
                  ? 'Receptor requerido con target'
                  : null;
            },
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _isTarget,
            onChanged: (v) => setState(() => _isTarget = v ?? false),
            title: const Text('Target'),
            contentPadding: EdgeInsets.zero,
          ),
          CheckboxListTile(
            value: _isCompletion,
            onChanged: (v) => setState(() {
              _isCompletion = v ?? false;
              if (_isCompletion) _isTarget = true;
              if (_isCompletion) _isDrop = false;
            }),
            title: const Text('Completo'),
            contentPadding: EdgeInsets.zero,
          ),
          CheckboxListTile(
            value: _isDrop,
            onChanged: (v) => setState(() {
              _isDrop = v ?? false;
              if (_isDrop) {
                _isTarget = true;
                _isCompletion = false;
              }
            }),
            title: const Text('Drop'),
            contentPadding: EdgeInsets.zero,
          ),
          CheckboxListTile(
            value: _isPassTd,
            onChanged: (v) => setState(() => _isPassTd = v ?? false),
            title: const Text('Pase TD'),
            contentPadding: EdgeInsets.zero,
          ),
        ],
        CheckboxListTile(
          value: _isRush,
          onChanged: (v) => setState(() => _isRush = v ?? false),
          title: const Text('Fue corrida'),
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          value: _isRushTd,
          onChanged: (v) => setState(() => _isRushTd = v ?? false),
          title: const Text('Corrida TD'),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _down,
                items: const [1, 2, 3, 4]
                    .map((d) =>
                        DropdownMenuItem<int>(value: d, child: Text('Down $d')))
                    .toList(),
                onChanged: (value) => setState(() => _down = value ?? 1),
                decoration: const InputDecoration(labelText: 'Down'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _distanceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Distancia'),
                validator: (value) {
                  final parsed = int.tryParse((value ?? '').trim());
                  if (parsed == null || parsed < 0) return 'Distancia inválida';
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDefenseForm() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: _defenderId,
          items: [
            const DropdownMenuItem<String>(
                value: '', child: Text('Sin jugador específico')),
            ...widget.players.map((p) => DropdownMenuItem(
                value: p.id, child: Text('#${p.jerseyNumber} ${p.fullName}'))),
          ],
          onChanged: (value) => setState(() =>
              _defenderId = (value == null || value.isEmpty) ? null : value),
          decoration:
              const InputDecoration(labelText: 'Jugador defensivo (opcional)'),
        ),
        CheckboxListTile(
          value: _isSack,
          onChanged: (v) => setState(() => _isSack = v ?? false),
          title: const Text('Sack'),
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          value: _isTackleFlag,
          onChanged: (v) => setState(() => _isTackleFlag = v ?? false),
          title: const Text('Tackle/Flag'),
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          value: _isInterception,
          onChanged: (v) => setState(() => _isInterception = v ?? false),
          title: const Text('Intercepción'),
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          value: _isPick6,
          onChanged: (v) => setState(() => _isPick6 = v ?? false),
          title: const Text('Pick-6'),
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          value: _isPassDefended,
          onChanged: (v) => setState(() => _isPassDefended = v ?? false),
          title: const Text('Pase defendido'),
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          value: _isPenalty,
          onChanged: (v) => setState(() => _isPenalty = v ?? false),
          title: const Text('Castigo'),
          contentPadding: EdgeInsets.zero,
        ),
        if (_isPenalty)
          TextFormField(
            controller: _penaltyController,
            decoration: const InputDecoration(labelText: 'Texto de castigo'),
          ),
      ],
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final yards = int.parse(_yardsController.text.trim());
    final distance = int.tryParse(_distanceController.text.trim());
    if (_unit == 'ofensiva' && (_qbId == null || _qbId!.trim().isEmpty)) return;

    final play = GamePlay(
      gameId: widget.gameId,
      half: _half,
      unit: _unit,
      down: _unit == 'ofensiva' ? _down : null,
      distanceYards: _unit == 'ofensiva' ? distance : null,
      yards: yards,
      points: _points,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      qbPlayerId: _unit == 'ofensiva' ? _qbId : null,
      receiverPlayerId: _unit == 'ofensiva' ? _receiverId : null,
      isTarget: _unit == 'ofensiva' ? _isTarget : false,
      isCompletion: _unit == 'ofensiva' ? _isCompletion : false,
      isDrop: _unit == 'ofensiva' ? _isDrop : false,
      isPassTd: _unit == 'ofensiva' ? _isPassTd : false,
      isRush: _unit == 'ofensiva' ? _isRush : false,
      isRushTd: _unit == 'ofensiva' ? _isRushTd : false,
      defenderPlayerId: _unit == 'defensiva' ? _defenderId : null,
      isSack: _unit == 'defensiva' ? _isSack : false,
      isTackleFlag: _unit == 'defensiva' ? _isTackleFlag : false,
      isInterception: _unit == 'defensiva' ? _isInterception : false,
      isPick6: _unit == 'defensiva' ? _isPick6 : false,
      isPassDefended: _unit == 'defensiva' ? _isPassDefended : false,
      isPenalty: _unit == 'defensiva' ? _isPenalty : false,
      penaltyText: (_unit == 'defensiva' &&
              _isPenalty &&
              _penaltyController.text.trim().isNotEmpty)
          ? _penaltyController.text.trim()
          : null,
    );

    Navigator.of(context)
        .pop(_PlayDraft(play: play, pointsForOur: _pointsForOur));
  }
}

String _playSubtitle(GamePlay play) {
  final chunks = <String>[];
  if ((play.description ?? '').trim().isNotEmpty) {
    chunks.add(play.description!.trim());
  }
  if ((play.notes ?? '').trim().isNotEmpty) chunks.add(play.notes!.trim());
  if (play.points > 0) chunks.add('Puntos: ${play.points}');
  if (play.unit == 'ofensiva') {
    if ((play.qbName ?? '').trim().isNotEmpty) chunks.add('QB: ${play.qbName}');
    if ((play.receiverName ?? '').trim().isNotEmpty) {
      chunks.add('Rec: ${play.receiverName}');
    }
    chunks.add('Down: ${play.down ?? '-'} & ${play.distanceYards ?? '-'}');
  } else {
    if ((play.defenderName ?? '').trim().isNotEmpty) {
      chunks.add('Def: ${play.defenderName}');
    }
    if (play.isSack) chunks.add('Sack');
    if (play.isTackleFlag) chunks.add('Tackle/Flag');
    if (play.isInterception) chunks.add('INT');
    if (play.isPick6) chunks.add('Pick-6');
    if (play.isPassDefended) chunks.add('Pase defendido');
    if (play.isPenalty) chunks.add('Castigo');
  }
  return chunks.isEmpty ? 'Sin detalle' : chunks.join(' • ');
}
