import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

import '../../core/player_profile_requirements.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/open_external_url.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/background_watermark.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading.dart';
import '../auth/providers/auth_providers.dart';
import '../seasons/providers/seasons_providers.dart';
import 'domain/player.dart';
import 'domain/player_completeness.dart';
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
                    return DefaultTabController(
                      length: 5,
                      child: Column(
                        children: [
                          _ProfileHeader(
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
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            child: statsAsync.when(
                              data: (stats) => _KpiGrid(
                                player: player,
                                stats: stats,
                              ),
                              loading: () => const SizedBox(
                                height: 80,
                                child:
                                    Center(child: CircularProgressIndicator()),
                              ),
                              error: (error, _) =>
                                  Text('Error cargando KPIs: $error'),
                            ),
                          ),
                          const TabBar(
                            isScrollable: true,
                            tabs: [
                              Tab(text: 'Perfil'),
                              Tab(text: 'Estadísticas'),
                              Tab(text: 'Bio'),
                              Tab(text: 'Splits'),
                              Tab(text: 'Resumen de Juegos'),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _ProfileTab(player: player),
                                _StatsTab(statsAsync: statsAsync),
                                _BioTab(
                                  controller: _bioController,
                                  canWrite: canWrite,
                                  saving: _savingBio,
                                  onSave:
                                      canWrite ? () => _saveBio(player) : null,
                                ),
                                const _SplitsTab(),
                                _GameLogTab(gameLogAsync: gameLogAsync),
                              ],
                            ),
                          ),
                        ],
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
          Row(
            children: [
              uiPhotoUrl.trim().isNotEmpty
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
                  : CircleAvatar(radius: 42, child: Text(player.initials)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
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
                ),
              ),
              if (canWrite && player.id != null)
                OutlinedButton.icon(
                  onPressed: () => context.push('/players/${player.id}/edit'),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar'),
                ),
            ],
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
  const _ProfileTab({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final missingLabels =
        PlayerCompletenessHelper.missingFieldLabelsForPlayer(player);
    final quality = missingLabels.isEmpty ? 'Completo' : 'Incompleto';
    return ListView(
      padding: const EdgeInsets.all(16),
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
  const _StatsTab({required this.statsAsync});

  final AsyncValue<PlayerSeasonStats> statsAsync;

  @override
  Widget build(BuildContext context) {
    return statsAsync.when(
      data: (stats) {
        return ListView(
          padding: const EdgeInsets.all(16),
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
    this.onSave,
  });

  final TextEditingController controller;
  final bool canWrite;
  final bool saving;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
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
  const _SplitsTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
            'Próximamente: splits por rival / tipo de partido / primer vs segundo tiempo.'),
      ),
    );
  }
}

class _GameLogTab extends StatelessWidget {
  const _GameLogTab({required this.gameLogAsync});

  final AsyncValue<List<PlayerGameLogRow>> gameLogAsync;

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
          padding: const EdgeInsets.all(16),
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
