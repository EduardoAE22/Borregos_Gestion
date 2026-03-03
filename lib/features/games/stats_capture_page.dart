import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/providers/auth_providers.dart';
import '../../core/utils/logger.dart';
import '../../shared/widgets/loading.dart';
import 'domain/stats.dart';
import 'providers/games_providers.dart';

class StatsCapturePage extends ConsumerStatefulWidget {
  const StatsCapturePage({
    super.key,
    required this.gameId,
    required this.type,
  });

  final String gameId;
  final String type;

  @override
  ConsumerState<StatsCapturePage> createState() => _StatsCapturePageState();
}

class _StatsCapturePageState extends ConsumerState<StatsCapturePage> {
  String? _selectedPlayerId;
  final Map<String, int> _values = {};
  bool _saving = false;

  String get _title {
    switch (widget.type) {
      case 'qb':
        return 'Captura QB';
      case 'skill':
        return 'Captura Skill';
      case 'def':
        return 'Captura Defensa';
      default:
        return 'Captura stats';
    }
  }

  List<String> get _fields {
    switch (widget.type) {
      case 'qb':
        return [
          'completions',
          'incompletions',
          'pass_tds',
          'interceptions',
          'rush_tds'
        ];
      case 'skill':
        return ['receptions', 'targets', 'rec_yards', 'rec_tds', 'drops'];
      case 'def':
        return ['tackles', 'sacks', 'interceptions', 'pick6', 'flags'];
      default:
        return const [];
    }
  }

  String _label(String key) {
    return key.replaceAll('_', ' ').toUpperCase();
  }

  void _setFromExisting(
    List<QBStat> qbStats,
    List<SkillStat> skillStats,
    List<DefStat> defStats,
  ) {
    if (_selectedPlayerId == null) return;

    if (widget.type == 'qb') {
      final stat =
          qbStats.where((s) => s.playerId == _selectedPlayerId).firstOrNull;
      _values['completions'] = stat?.completions ?? 0;
      _values['incompletions'] = stat?.incompletions ?? 0;
      _values['pass_tds'] = stat?.passTds ?? 0;
      _values['interceptions'] = stat?.interceptions ?? 0;
      _values['rush_tds'] = stat?.rushTds ?? 0;
      return;
    }

    if (widget.type == 'skill') {
      final stat =
          skillStats.where((s) => s.playerId == _selectedPlayerId).firstOrNull;
      _values['receptions'] = stat?.receptions ?? 0;
      _values['targets'] = stat?.targets ?? 0;
      _values['rec_yards'] = stat?.recYards ?? 0;
      _values['rec_tds'] = stat?.recTds ?? 0;
      _values['drops'] = stat?.drops ?? 0;
      return;
    }

    final stat =
        defStats.where((s) => s.playerId == _selectedPlayerId).firstOrNull;
    _values['tackles'] = stat?.tackles ?? 0;
    _values['sacks'] = stat?.sacks ?? 0;
    _values['interceptions'] = stat?.interceptions ?? 0;
    _values['pick6'] = stat?.pick6 ?? 0;
    _values['flags'] = stat?.flags ?? 0;
  }

  Future<void> _save() async {
    final profile = await ref.read(currentProfileProvider.future);
    if (!(profile?.canWriteGeneral ?? false)) return;
    if (_selectedPlayerId == null) return;

    setState(() => _saving = true);

    try {
      final repo = ref.read(statsRepoProvider);
      if (widget.type == 'qb') {
        await repo.upsertQBStat(
          gameId: widget.gameId,
          playerId: _selectedPlayerId!,
          completions: _values['completions'] ?? 0,
          incompletions: _values['incompletions'] ?? 0,
          passTds: _values['pass_tds'] ?? 0,
          interceptions: _values['interceptions'] ?? 0,
          rushTds: _values['rush_tds'] ?? 0,
        );
        ref.invalidate(qbStatsProvider(widget.gameId));
      } else if (widget.type == 'skill') {
        await repo.upsertSkillStat(
          gameId: widget.gameId,
          playerId: _selectedPlayerId!,
          receptions: _values['receptions'] ?? 0,
          targets: _values['targets'] ?? 0,
          recYards: _values['rec_yards'] ?? 0,
          recTds: _values['rec_tds'] ?? 0,
          drops: _values['drops'] ?? 0,
        );
        ref.invalidate(skillStatsProvider(widget.gameId));
      } else {
        await repo.upsertDefStat(
          gameId: widget.gameId,
          playerId: _selectedPlayerId!,
          tackles: _values['tackles'] ?? 0,
          sacks: _values['sacks'] ?? 0,
          interceptions: _values['interceptions'] ?? 0,
          pick6: _values['pick6'] ?? 0,
          flags: _values['flags'] ?? 0,
        );
        ref.invalidate(defStatsProvider(widget.gameId));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stats guardadas.')),
      );
    } on PostgrestException catch (e) {
      AppLogger.supabaseError(e, scope: 'Games.statsSave');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _counterField(String key) {
    final value = _values[key] ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(_label(key))),
            IconButton(
              onPressed: () {
                setState(() {
                  final current = _values[key] ?? 0;
                  _values[key] = current > 0 ? current - 1 : 0;
                });
              },
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text(value.toString(),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              onPressed: () {
                setState(() {
                  _values[key] = (_values[key] ?? 0) + 1;
                });
              },
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final gameAsync = ref.watch(gameByIdProvider(widget.gameId));
    final qbStatsAsync = ref.watch(qbStatsProvider(widget.gameId));
    final skillStatsAsync = ref.watch(skillStatsProvider(widget.gameId));
    final defStatsAsync = ref.watch(defStatsProvider(widget.gameId));

    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: gameAsync.when(
        data: (game) {
          if (game == null) {
            return const Center(child: Text('Partido no encontrado.'));
          }
          if (game.seasonId == null || game.seasonId!.trim().isEmpty) {
            return const Center(
              child: Text(
                  'Esta captura aplica solo a partidos de torneo con temporada.'),
            );
          }

          final rosterAsync = ref.watch(rosterBySeasonProvider(game.seasonId!));

          return rosterAsync.when(
            data: (roster) {
              return profileAsync.when(
                data: (profile) {
                  final canWrite = profile?.canWriteGeneral ?? false;

                  final qbStats = qbStatsAsync.valueOrNull ?? const <QBStat>[];
                  final skillStats =
                      skillStatsAsync.valueOrNull ?? const <SkillStat>[];
                  final defStats =
                      defStatsAsync.valueOrNull ?? const <DefStat>[];

                  if (_selectedPlayerId == null && roster.isNotEmpty) {
                    _selectedPlayerId = roster.first.id;
                    _setFromExisting(qbStats, skillStats, defStats);
                  }

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: ListTile(
                          title: Text('vs ${game.opponent}'),
                          subtitle: Text(
                              game.gameDate.toIso8601String().split('T').first),
                          trailing: Text('${game.ourScore} - ${game.oppScore}'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedPlayerId,
                        decoration: const InputDecoration(labelText: 'Jugador'),
                        items: roster
                            .map((p) => DropdownMenuItem(
                                value: p.id, child: Text(p.displayName)))
                            .toList(),
                        onChanged: (value) {
                          setState(() => _selectedPlayerId = value);
                          _setFromExisting(qbStats, skillStats, defStats);
                        },
                      ),
                      const SizedBox(height: 12),
                      ..._fields.map(_counterField),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: canWrite && !_saving ? _save : null,
                        child: Text(_saving ? 'Guardando...' : 'Guardar'),
                      ),
                      if (!canWrite)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('Modo solo lectura para este rol.'),
                        ),
                      const SizedBox(height: 16),
                      Text('Stats actuales',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (widget.type == 'qb') _qbTable(qbStats),
                      if (widget.type == 'skill') _skillTable(skillStats),
                      if (widget.type == 'def') _defTable(defStats),
                    ],
                  );
                },
                loading: () => const Loading(message: 'Cargando permisos...'),
                error: (error, stack) => Center(child: Text('Error: $error')),
              );
            },
            loading: () => const Loading(message: 'Cargando roster...'),
            error: (error, stack) => Center(child: Text('Error: $error')),
          );
        },
        loading: () => const Loading(message: 'Cargando partido...'),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _qbTable(List<QBStat> stats) {
    if (stats.isEmpty) return const Text('Sin stats QB.');
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Jugador')),
          DataColumn(label: Text('Comp')),
          DataColumn(label: Text('Incomp')),
          DataColumn(label: Text('Pass TD')),
          DataColumn(label: Text('INT')),
          DataColumn(label: Text('Rush TD')),
        ],
        rows: stats
            .map(
              (s) => DataRow(cells: [
                DataCell(Text(s.playerName)),
                DataCell(Text('${s.completions}')),
                DataCell(Text('${s.incompletions}')),
                DataCell(Text('${s.passTds}')),
                DataCell(Text('${s.interceptions}')),
                DataCell(Text('${s.rushTds}')),
              ]),
            )
            .toList(),
      ),
    );
  }

  Widget _skillTable(List<SkillStat> stats) {
    if (stats.isEmpty) return const Text('Sin stats Skill.');
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Jugador')),
          DataColumn(label: Text('Rec')),
          DataColumn(label: Text('Tgt')),
          DataColumn(label: Text('Yds')),
          DataColumn(label: Text('TD')),
          DataColumn(label: Text('Drops')),
        ],
        rows: stats
            .map(
              (s) => DataRow(cells: [
                DataCell(Text(s.playerName)),
                DataCell(Text('${s.receptions}')),
                DataCell(Text('${s.targets}')),
                DataCell(Text('${s.recYards}')),
                DataCell(Text('${s.recTds}')),
                DataCell(Text('${s.drops}')),
              ]),
            )
            .toList(),
      ),
    );
  }

  Widget _defTable(List<DefStat> stats) {
    if (stats.isEmpty) return const Text('Sin stats Defensa.');
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Jugador')),
          DataColumn(label: Text('Tkl')),
          DataColumn(label: Text('Sacks')),
          DataColumn(label: Text('INT')),
          DataColumn(label: Text('Pick6')),
          DataColumn(label: Text('Flags')),
        ],
        rows: stats
            .map(
              (s) => DataRow(cells: [
                DataCell(Text(s.playerName)),
                DataCell(Text('${s.tackles}')),
                DataCell(Text('${s.sacks}')),
                DataCell(Text('${s.interceptions}')),
                DataCell(Text('${s.pick6}')),
                DataCell(Text('${s.flags}')),
              ]),
            )
            .toList(),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
