import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

import '../../core/player_profile_requirements.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/open_external_url.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/background_watermark.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading.dart';
import '../auth/providers/auth_providers.dart';
import '../seasons/providers/seasons_providers.dart';
import 'domain/player.dart';
import 'domain/combine.dart';
import 'domain/player_completeness.dart';
import 'providers/combine_providers.dart';
import 'providers/player_profile_providers.dart';
import 'providers/player_photo_providers.dart';
import 'providers/players_providers.dart';

class PlayerProfilePage extends ConsumerStatefulWidget {
  const PlayerProfilePage({
    super.key,
    required this.playerId,
  });

  final String playerId;

  @override
  ConsumerState<PlayerProfilePage> createState() => _PlayerProfilePageState();
}

class _PlayerProfilePageState extends ConsumerState<PlayerProfilePage> {
  final _bioController = TextEditingController();
  bool _bioInitialized = false;
  bool _savingBio = false;
  String? _lastLoggedPhotoUrl;

  @override
  void initState() {
    super.initState();
    AppLogger.info('Nav',
        'Entrando a PlayerProfilePage(${widget.playerId}) @ ${DateTime.now().toIso8601String()}');
  }

  Future<void> _onDiagnosticAction(String url) async {
    if (url.trim().isEmpty) return;

    if (kIsWeb) {
      final opened = await openExternalUrl(url);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(opened
                ? 'URL abierta en nueva pestaña.'
                : 'No se pudo abrir la URL.')),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('URL copiada al portapapeles.')),
    );
  }

  void _retryPhotoLoad(String? photoPath) {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    ref.read(playerPhotoSignedUrlServiceProvider).evict(photoPath);
    ref.invalidate(playerByIdProvider(widget.playerId));
    setState(() {});
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerAsync = ref.watch(playerByIdProvider(widget.playerId));
    final profileAsync = ref.watch(currentProfileProvider);
    final seasonAsync = ref.watch(activeSeasonProvider);
    final statsAsync = ref.watch(playerSeasonStatsProvider(widget.playerId));
    final gameLogAsync = ref.watch(playerGameLogProvider(widget.playerId));

    return AppScaffold(
      title: 'Perfil de jugador',
      selectedNavIndex: 0,
      actions: [
        TextButton.icon(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.secondary,
          ),
          onPressed: () {
            final navigator = Navigator.of(context);
            if (navigator.canPop()) {
              navigator.pop();
            }
          },
          icon: const Icon(Icons.arrow_back),
          label: const Text('Volver'),
        ),
      ],
      body: WatermarkedBody(
        child: playerAsync.when(
          data: (player) {
            if (player == null) {
              return const EmptyState(
                title: 'Jugador no encontrado',
                message: 'No se encontró el jugador solicitado.',
                icon: Icons.person_off_outlined,
              );
            }
            if (!_bioInitialized) {
              _bioController.text = player.notes ?? '';
              _bioInitialized = true;
            }
            final signedPhotoAsync =
                ref.watch(playerPhotoSignedUrlProvider(player.photoPath));
            final uiPhotoUrl = signedPhotoAsync.valueOrNull ?? '';
            if (_lastLoggedPhotoUrl != uiPhotoUrl) {
              _lastLoggedPhotoUrl = uiPhotoUrl;
              AppLogger.info('PlayerProfile.photoUrl',
                  'playerId=${player.id} photoPath=${player.photoPath} signedPhotoUrl=$uiPhotoUrl');
            }

            return profileAsync.when(
              data: (profile) {
                final canWrite = profile?.canWriteGeneral ?? false;
                return seasonAsync.when(
                  data: (season) {
                    final seasonName = season?.name ?? 'Sin temporada activa';
                    final seasonId = season?.id;
                    final bottomPadding =
                        MediaQuery.of(context).padding.bottom +
                            kBottomNavigationBarHeight +
                            16;
                    return DefaultTabController(
                      length: 6,
                      child: NestedScrollView(
                        headerSliverBuilder: (context, innerBoxIsScrolled) {
                          return [
                            SliverToBoxAdapter(
                              child: _ProfileHeader(
                                player: player,
                                uiPhotoUrl: uiPhotoUrl,
                                onDiagnosticAction: uiPhotoUrl.isEmpty
                                    ? null
                                    : () => _onDiagnosticAction(uiPhotoUrl),
                                onRetryPhoto: () =>
                                    _retryPhotoLoad(player.photoPath),
                                seasonName: seasonName,
                                canWrite: canWrite,
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 8),
                                child: statsAsync.when(
                                  data: (stats) => _KpiGrid(
                                    player: player,
                                    stats: stats,
                                  ),
                                  loading: () => const SizedBox(
                                    height: 80,
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                  error: (error, _) =>
                                      Text('Error cargando KPIs: $error'),
                                ),
                              ),
                            ),
                            SliverPersistentHeader(
                              pinned: true,
                              delegate: _TabBarHeaderDelegate(
                                child: PreferredSize(
                                  preferredSize:
                                      const Size.fromHeight(kTextTabBarHeight),
                                  child: Container(
                                    color: Theme.of(context)
                                        .scaffoldBackgroundColor,
                                    child: const TabBar(
                                      isScrollable: true,
                                      tabs: [
                                        Tab(text: 'Perfil'),
                                        Tab(text: 'Estadísticas'),
                                        Tab(text: 'Bio'),
                                        Tab(text: 'Splits'),
                                        Tab(text: 'Resumen de Juegos'),
                                        Tab(text: 'Combine'),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ];
                        },
                        body: TabBarView(
                          children: [
                            _ProfileTab(
                              player: player,
                              bottomPadding: bottomPadding,
                            ),
                            _StatsTab(
                              statsAsync: statsAsync,
                              bottomPadding: bottomPadding,
                            ),
                            _BioTab(
                              controller: _bioController,
                              canWrite: canWrite,
                              saving: _savingBio,
                              onSave: canWrite ? () => _saveBio(player) : null,
                              bottomPadding: bottomPadding,
                            ),
                            _SplitsTab(bottomPadding: bottomPadding),
                            _GameLogTab(
                              gameLogAsync: gameLogAsync,
                              bottomPadding: bottomPadding,
                            ),
                            _CombineTab(
                              seasonId: seasonId,
                              playerId: widget.playerId,
                              bottomPadding: bottomPadding,
                              onCreateSession: seasonId == null
                                  ? null
                                  : () => _openCreateCombineSessionSheet(
                                        seasonId,
                                      ),
                              onEditResults: seasonId == null
                                  ? null
                                  : (session, tests, current) =>
                                      _openCombineResultsSheet(
                                        seasonId: seasonId,
                                        session: session,
                                        tests: tests,
                                        currentByTestId: current,
                                      ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  loading: () =>
                      const Loading(message: 'Cargando temporada activa...'),
                  error: (error, _) => Center(child: Text('Error: $error')),
                );
              },
              loading: () => const Loading(message: 'Cargando permisos...'),
              error: (error, _) => Center(child: Text('Error: $error')),
            );
          },
          loading: () => const Loading(message: 'Cargando perfil...'),
          error: (error, _) => Center(child: Text('Error: $error')),
        ),
      ),
    );
  }

  Future<void> _saveBio(Player player) async {
    setState(() => _savingBio = true);
    try {
      await ref.read(playersRepoProvider).upsertPlayer(
            player.copyWith(
              notes: _bioController.text.trim().isEmpty
                  ? null
                  : _bioController.text.trim(),
            ),
          );
      ref.invalidate(playerByIdProvider(widget.playerId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bio actualizada.')),
      );
    } finally {
      if (mounted) setState(() => _savingBio = false);
    }
  }

  Future<void> _openCreateCombineSessionSheet(String seasonId) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreateCombineSessionSheet(
        seasonId: seasonId,
        onSaved: () {
          ref.invalidate(combineSessionsByActiveSeasonProvider);
        },
      ),
    );
  }

  Future<void> _openCombineResultsSheet({
    required String seasonId,
    required CombineSession session,
    required List<CombineTest> tests,
    required Map<String, CombineResult> currentByTestId,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CombineResultsSheet(
        seasonId: seasonId,
        playerId: widget.playerId,
        session: session,
        tests: tests,
        currentByTestId: currentByTestId,
        onSaved: () {
          ref.invalidate(
            combinePlayerResultsProvider(
              (
                sessionId: session.id,
                playerId: widget.playerId,
              ),
            ),
          );
          ref.invalidate(
            combineRankingsProvider(
              (
                sessionId: session.id,
                testId: tests.isEmpty ? '' : tests.first.id,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.player,
    required this.uiPhotoUrl,
    required this.onDiagnosticAction,
    required this.onRetryPhoto,
    required this.seasonName,
    required this.canWrite,
  });

  final Player player;
  final String uiPhotoUrl;
  final VoidCallback? onDiagnosticAction;
  final VoidCallback onRetryPhoto;
  final String seasonName;
  final bool canWrite;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      Chip(label: Text('#${player.jerseyNumber}')),
      Chip(label: Text(player.position ?? 'Sin posición')),
      Chip(label: Text(player.isActive ? 'Activo' : 'Inactivo')),
    ];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 560;
              final avatar = uiPhotoUrl.trim().isNotEmpty
                  ? RepaintBoundary(
                      child: CircleAvatar(
                        radius: 42,
                        child: ClipOval(
                          child: SizedBox.expand(
                            child: Image.network(
                              uiPhotoUrl,
                              key: ValueKey(uiPhotoUrl),
                              gaplessPlayback: true,
                              fit: BoxFit.cover,
                              cacheWidth: 256,
                              cacheHeight: 256,
                              errorBuilder: (_, error, ___) {
                                var detail = '';
                                if (error is NetworkImageLoadException) {
                                  AppLogger.info(
                                    'PlayerProfile.image',
                                    'status=${error.statusCode} url=${error.uri}',
                                  );
                                  if (error.statusCode == 403 ||
                                      error.statusCode == 404) {
                                    detail = ' (${error.statusCode})';
                                  }
                                } else {
                                  AppLogger.info(
                                    'PlayerProfile.image',
                                    'error=$error url=$uiPhotoUrl',
                                  );
                                }
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Error cargando foto$detail',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall,
                                    ),
                                    TextButton(
                                      onPressed: onRetryPhoto,
                                      child: const Text('Reintentar'),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    )
                  : CircleAvatar(radius: 42, child: Text(player.initials));
              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${player.firstName} ${player.lastName}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Borregos Gestión • $seasonName',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 8, children: chips),
                ],
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        avatar,
                        const SizedBox(width: 14),
                        Expanded(child: details),
                      ],
                    ),
                    if (canWrite && player.id != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              context.push('/players/${player.id}/edit'),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Editar'),
                        ),
                      ),
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  avatar,
                  const SizedBox(width: 14),
                  Expanded(child: details),
                  if (canWrite && player.id != null)
                    OutlinedButton.icon(
                      onPressed: () =>
                          context.push('/players/${player.id}/edit'),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Editar'),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Resumen: ${_safeNum(player.heightCm, 'cm')} • ${_safeNum(player.weightKg, 'kg')} • ${player.age != null ? '${player.age} años' : 'Edad N/D'}',
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Text(
              'Diagnóstico foto (debug)',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            SelectableText(
              uiPhotoUrl.isEmpty
                  ? 'photo_path: (vacío)'
                  : 'photo_path: ${player.photoPath ?? '-'}\nsigned_url: $uiPhotoUrl',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: onDiagnosticAction,
                icon: Icon(kIsWeb ? Icons.open_in_new : Icons.copy_outlined),
                label: Text(kIsWeb ? 'Abrir URL' : 'Copiar URL'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _safeNum(num? value, String unit) {
    if (value == null || value <= 0) return '$unit N/D';
    return '$value $unit';
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({
    required this.player,
    required this.stats,
  });

  final Player player;
  final PlayerSeasonStats stats;

  @override
  Widget build(BuildContext context) {
    final pos = (player.position ?? '').toUpperCase();
    final isQb = pos.contains('QB');
    final isWr =
        pos.contains('WR') || pos.contains('REC') || pos.contains('CB');

    final entries = <({String label, String value})>[
      if (isQb)
        (
          label: 'Comp/Att',
          value: '${stats.passCompletions}/${stats.passAttempts}'
        ),
      if (isQb) (label: 'Yds Pase', value: '${stats.passYards}'),
      if (isQb) (label: 'TD Pase', value: '${stats.passTds}'),
      if (isQb) (label: 'INT', value: '${stats.interceptionsThrown}'),
      if (isWr)
        (label: 'Rec/Targets', value: '${stats.receptions}/${stats.targets}'),
      if (isWr) (label: 'Drops', value: '${stats.drops}'),
      if (isWr) (label: 'Yds Rec', value: '${stats.recYards}'),
      if (isWr) (label: 'TD Rec', value: '${stats.recTds}'),
      if (!isQb && !isWr)
        (label: 'Intercepciones', value: '${stats.defInterceptions}'),
      if (!isQb && !isWr) (label: 'Sacks', value: '${stats.sacks}'),
      if (!isQb && !isWr)
        (label: 'Flags/Tackles', value: '${stats.flagsPulled}'),
      if (!isQb && !isWr) (label: 'Pick-6', value: '${stats.pick6}'),
    ];

    if (entries.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('Aún sin jugadas registradas'),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 420 ? 2 : 3;
        final spacing = 8.0;
        final tileWidth =
            (constraints.maxWidth - (columns - 1) * spacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: entries.map((e) {
            return SizedBox(
              width: tileWidth,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(e.value,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      e.label,
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }).toList(growable: false),
        );
      },
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.player,
    required this.bottomPadding,
  });

  final Player player;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final missingLabels =
        PlayerCompletenessHelper.missingFieldLabelsForPlayer(player);
    final quality = missingLabels.isEmpty ? 'Completo' : 'Incompleto';
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
      children: [
        Card(
          child: ListTile(
            title: const Text('Calidad de datos'),
            subtitle: Text(
              missingLabels.isEmpty
                  ? 'Sin faltantes'
                  : 'Faltan: ${missingLabels.join(', ')}',
            ),
            trailing: Chip(label: Text(quality)),
          ),
        ),
        _infoTile('Teléfono', player.phone),
        _infoTile('Contacto emergencia', player.emergencyContact),
        _infoTile(
            'Altura', player.heightCm == null ? null : '${player.heightCm} cm'),
        _infoTile(
            'Peso', player.weightKg == null ? null : '${player.weightKg} kg'),
        _infoTile('Edad', player.age == null ? null : '${player.age} años'),
        _infoTile('Talla', player.jerseySize),
        _infoTile('Género', player.uniformGender),
        _infoTile('Nombre en jersey', player.jerseyName),
        _infoTile('Notas', player.notes),
      ],
    );
  }

  Widget _infoTile(String label, String? value) {
    return Card(
      child: ListTile(
        title: Text(label),
        subtitle: Text((value ?? '').trim().isEmpty ? 'N/D' : value!),
      ),
    );
  }
}

class _StatsTab extends StatelessWidget {
  const _StatsTab({
    required this.statsAsync,
    required this.bottomPadding,
  });

  final AsyncValue<PlayerSeasonStats> statsAsync;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return statsAsync.when(
      data: (stats) {
        return ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ofensiva',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                        'QB Comp/Att: ${stats.passCompletions}/${stats.passAttempts}'),
                    Text('Yardas pase: ${stats.passYards}'),
                    Text('TD pase: ${stats.passTds}'),
                    Text('INT lanzadas: ${stats.interceptionsThrown}'),
                    Text('Targets: ${stats.targets}'),
                    Text('Recepciones: ${stats.receptions}'),
                    Text('Drops: ${stats.drops}'),
                    Text('Yardas recepción: ${stats.recYards}'),
                    Text('TD recepción: ${stats.recTds}'),
                  ],
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Defensa',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('Intercepciones: ${stats.defInterceptions}'),
                    Text('Pick-6: ${stats.pick6}'),
                    Text('Sacks: ${stats.sacks}'),
                    Text('Pressures: ${stats.pressures}'),
                    Text('Flags/Tackles: ${stats.flagsPulled}'),
                    Text('Pases defendidos: ${stats.passesDefended}'),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Loading(message: 'Calculando estadísticas...'),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }
}

class _BioTab extends StatelessWidget {
  const _BioTab({
    required this.controller,
    required this.canWrite,
    required this.saving,
    required this.bottomPadding,
    this.onSave,
  });

  final TextEditingController controller;
  final bool canWrite;
  final bool saving;
  final double bottomPadding;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
      children: [
        TextField(
          controller: controller,
          maxLines: 8,
          readOnly: !canWrite,
          decoration: const InputDecoration(
            labelText: 'Bio',
            hintText: 'Escribe una bio del jugador',
          ),
        ),
        const SizedBox(height: 12),
        if (canWrite)
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: saving ? null : onSave,
              child: Text(saving ? 'Guardando...' : 'Guardar bio'),
            ),
          )
        else
          const Text('Solo lectura'),
      ],
    );
  }
}

class _SplitsTab extends StatelessWidget {
  const _SplitsTab({required this.bottomPadding});

  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
      child: const Center(
        child: Text(
            'Próximamente: splits por rival / tipo de partido / primer vs segundo tiempo.'),
      ),
    );
  }
}

class _GameLogTab extends StatelessWidget {
  const _GameLogTab({
    required this.gameLogAsync,
    required this.bottomPadding,
  });

  final AsyncValue<List<PlayerGameLogRow>> gameLogAsync;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return gameLogAsync.when(
      data: (rows) {
        if (rows.isEmpty) {
          return const EmptyState(
            title: 'Sin juegos',
            message: 'Aún no hay jugadas para generar game log.',
            icon: Icons.sports_football_outlined,
          );
        }

        return ListView.separated(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final row = rows[index];
            final date = row.date.toIso8601String().split('T').first;
            final type = _typeLabel(row.gameType);
            return Card(
              child: ListTile(
                onTap: () => context.push('/games/${row.gameId}'),
                title: Text('$date • vs ${row.opponent}'),
                subtitle: Text(
                  '$type • ${row.result} (${row.ourScore}-${row.oppScore})\n'
                  'Jugadas:${row.plays} Yds:${row.yards} Rec/Target:${row.receptions}/${row.targets} TD:${row.tds}',
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
      loading: () => const Loading(message: 'Cargando resumen de juegos...'),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  String _typeLabel(String gameType) {
    switch (PlayerProfileRequirements.normalizeKey(gameType)) {
      default:
        if (gameType == 'amistoso') return 'Amistoso';
        if (gameType == 'interno') return 'Interno';
        return 'Torneo';
    }
  }
}

class _CombineTab extends ConsumerStatefulWidget {
  const _CombineTab({
    required this.seasonId,
    required this.playerId,
    required this.bottomPadding,
    this.onCreateSession,
    this.onEditResults,
  });

  final String? seasonId;
  final String playerId;
  final double bottomPadding;
  final VoidCallback? onCreateSession;
  final void Function(
    CombineSession session,
    List<CombineTest> tests,
    Map<String, CombineResult> currentByTestId,
  )? onEditResults;

  @override
  ConsumerState<_CombineTab> createState() => _CombineTabState();
}

class _CombineTabState extends ConsumerState<_CombineTab> {
  String? _selectedSessionId;

  @override
  Widget build(BuildContext context) {
    if (widget.seasonId == null) {
      return const EmptyState(
        title: 'Sin temporada activa',
        message: 'Selecciona una temporada para capturar Combine.',
        icon: Icons.calendar_month_outlined,
      );
    }

    final sessionsAsync = ref.watch(combineSessionsByActiveSeasonProvider);
    final testsAsync = ref.watch(combineTestsProvider);
    if (sessionsAsync.isLoading || testsAsync.isLoading) {
      return const Loading(message: 'Cargando combine...');
    }
    if (sessionsAsync.hasError) {
      return Center(
          child: Text('Error cargando sesiones: ${sessionsAsync.error}'));
    }
    if (testsAsync.hasError) {
      return Center(child: Text('Error cargando pruebas: ${testsAsync.error}'));
    }

    final sessions = sessionsAsync.valueOrNull ?? const <CombineSession>[];
    final tests = testsAsync.valueOrNull ?? const <CombineTest>[];

    if (sessions.isEmpty) {
      return ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, widget.bottomPadding),
        children: [
          const EmptyState(
            title: 'Sin sesiones de Combine',
            message: 'Crea una sesión para comenzar a capturar resultados.',
            icon: Icons.fitness_center_outlined,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: widget.onCreateSession,
            icon: const Icon(Icons.add),
            label: const Text('Crear sesión'),
          ),
        ],
      );
    }

    _selectedSessionId ??= sessions.first.id;
    final selectedSession = sessions.firstWhere(
      (session) => session.id == _selectedSessionId,
      orElse: () => sessions.first,
    );
    final resultsAsync = ref.watch(
      combinePlayerResultsProvider(
        (
          sessionId: selectedSession.id,
          playerId: widget.playerId,
        ),
      ),
    );

    return resultsAsync.when(
      data: (currentByTestId) {
        return ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, widget.bottomPadding),
          children: [
            DropdownButtonFormField<String>(
              initialValue: selectedSession.id,
              decoration: const InputDecoration(labelText: 'Sesión'),
              items: sessions
                  .map(
                    (session) => DropdownMenuItem(
                      value: session.id,
                      child: Text(
                        '${session.nombre} • ${AppFormatters.date(session.fecha)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedSessionId = value);
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: widget.onCreateSession,
                  icon: const Icon(Icons.add),
                  label: const Text('Crear sesión'),
                ),
                FilledButton.icon(
                  onPressed: widget.onEditResults == null
                      ? null
                      : () => widget.onEditResults!(
                            selectedSession,
                            tests,
                            currentByTestId,
                          ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Registrar/Editar resultados'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (tests.isEmpty)
              const EmptyState(
                title: 'Sin pruebas activas',
                message: 'No hay pruebas de combine activas para mostrar.',
                icon: Icons.list_alt_outlined,
              )
            else
              ...tests.map((test) {
                final result = currentByTestId[test.id];
                final hasValue = result != null;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(test.nombre),
                    subtitle: Text(
                      hasValue
                          ? _buildResultLabel(test, result)
                          : 'Sin registro',
                    ),
                    trailing: Chip(
                      label: Text(hasValue ? 'Registrado' : 'Pendiente'),
                    ),
                  ),
                );
              }),
          ],
        );
      },
      loading: () => const Loading(message: 'Cargando resultados...'),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  String _buildResultLabel(CombineTest test, CombineResult result) {
    final base = '${result.valor} ${test.unidad}';
    if (test.codigo != 'dash_40') return base;
    final splits = <String>[];
    if (result.split10 != null) splits.add('10y: ${result.split10}');
    if (result.split20 != null) splits.add('20y: ${result.split20}');
    if (splits.isEmpty) return base;
    return '$base • ${splits.join(' · ')}';
  }
}

class _CreateCombineSessionSheet extends ConsumerStatefulWidget {
  const _CreateCombineSessionSheet({
    required this.seasonId,
    required this.onSaved,
  });

  final String seasonId;
  final VoidCallback onSaved;

  @override
  ConsumerState<_CreateCombineSessionSheet> createState() =>
      _CreateCombineSessionSheetState();
}

class _CreateCombineSessionSheetState
    extends ConsumerState<_CreateCombineSessionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _notasController = TextEditingController();
  DateTime _fecha = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  Future<void> _pickFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _fecha = DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(combineRepoProvider).createSession(
            seasonId: widget.seasonId,
            nombre: _nombreController.text.trim(),
            fecha: _fecha,
            notas: _notasController.text.trim(),
          );
      if (!mounted) return;
      widget.onSaved();
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo crear sesión: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Crear sesión de Combine',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    hintText: 'Ej. Combine Marzo 2026',
                  ),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fecha'),
                  subtitle: Text(AppFormatters.date(_fecha)),
                  trailing: TextButton(
                    onPressed: _saving ? null : _pickFecha,
                    child: const Text('Cambiar'),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _notasController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notas'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Guardando...' : 'Guardar sesión'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CombineResultsSheet extends ConsumerStatefulWidget {
  const _CombineResultsSheet({
    required this.seasonId,
    required this.playerId,
    required this.session,
    required this.tests,
    required this.currentByTestId,
    required this.onSaved,
  });

  final String seasonId;
  final String playerId;
  final CombineSession session;
  final List<CombineTest> tests;
  final Map<String, CombineResult> currentByTestId;
  final VoidCallback onSaved;

  @override
  ConsumerState<_CombineResultsSheet> createState() =>
      _CombineResultsSheetState();
}

class _CombineResultsSheetState extends ConsumerState<_CombineResultsSheet> {
  late final Map<String, TextEditingController> _valueControllers;
  final Map<String, TextEditingController> _split10Controllers = {};
  final Map<String, TextEditingController> _split20Controllers = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _valueControllers = {
      for (final test in widget.tests)
        test.id: TextEditingController(
          text: widget.currentByTestId[test.id]?.valor.toString() ?? '',
        ),
    };

    for (final test in widget.tests.where((test) => test.codigo == 'dash_40')) {
      final current = widget.currentByTestId[test.id];
      _split10Controllers[test.id] =
          TextEditingController(text: current?.split10?.toString() ?? '');
      _split20Controllers[test.id] =
          TextEditingController(text: current?.split20?.toString() ?? '');
    }
  }

  @override
  void dispose() {
    for (final controller in _valueControllers.values) {
      controller.dispose();
    }
    for (final controller in _split10Controllers.values) {
      controller.dispose();
    }
    for (final controller in _split20Controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _tryParse(String text) {
    final clean = text.trim().replaceAll(',', '.');
    if (clean.isEmpty) return null;
    return double.tryParse(clean);
  }

  Future<void> _save() async {
    final inputs = <CombineResultInput>[];
    for (final test in widget.tests) {
      final raw = _valueControllers[test.id]!.text;
      final value = _tryParse(raw);
      if (value == null) continue;

      Map<String, dynamic>? extras;
      if (test.codigo == 'dash_40') {
        extras = buildCombineExtras(
          split10: _tryParse(_split10Controllers[test.id]?.text ?? ''),
          split20: _tryParse(_split20Controllers[test.id]?.text ?? ''),
        );
      }

      inputs.add(
        CombineResultInput(
          testId: test.id,
          valor: value,
          extras: extras,
          intento: 1,
        ),
      );
    }

    if (inputs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Captura al menos un resultado.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(combineRepoProvider).upsertPlayerResults(
            sessionId: widget.session.id,
            playerId: widget.playerId,
            results: inputs,
          );
      if (!mounted) return;
      widget.onSaved();
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron guardar resultados: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Resultados Combine',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.session.nombre} • ${AppFormatters.date(widget.session.fecha)}',
              ),
              const SizedBox(height: 12),
              ...widget.tests.map((test) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          test.nombre,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _valueControllers[test.id],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Valor (${test.unidad})',
                          ),
                        ),
                        if (test.codigo == 'dash_40') ...[
                          const SizedBox(height: 8),
                          ExpansionTile(
                            title: const Text('Avanzado (opcional)'),
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: EdgeInsets.zero,
                            children: [
                              TextFormField(
                                controller: _split10Controllers[test.id],
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                    labelText: 'Split 10y'),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _split20Controllers[test.id],
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                    labelText: 'Split 20y'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Guardando...' : 'Guardar resultados'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _TabBarHeaderDelegate({required this.child});

  final PreferredSizeWidget child;

  @override
  double get minExtent => child.preferredSize.height;

  @override
  double get maxExtent => child.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _TabBarHeaderDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}
