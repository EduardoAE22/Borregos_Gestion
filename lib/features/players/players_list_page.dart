import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/app_strings.dart';
import '../../core/utils/logger.dart';
import '../auth/providers/auth_providers.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/background_watermark.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading.dart';
import 'domain/player.dart';
import 'providers/player_photo_providers.dart';
import 'providers/players_providers.dart';

class PlayersListPage extends ConsumerStatefulWidget {
  const PlayersListPage({super.key});

  @override
  ConsumerState<PlayersListPage> createState() => _PlayersListPageState();
}

class _PlayersListPageState extends ConsumerState<PlayersListPage> {
  static const int _precacheCount = 10;
  final _searchController = TextEditingController();
  bool _onlyActive = true;
  String _lastPhotoSnapshotLog = '';
  late Stopwatch _pageToDataStopwatch;
  late Stopwatch _pageToFirstImagesStopwatch;
  bool _loggedPlayersDataReady = false;
  bool _loggedFirstTenImages = false;
  final Set<String> _firstRenderedImagePlayers = <String>{};
  final Map<String, int> _itemBuildCountByPlayerId = <String, int>{};
  String _lastPrecacheSnapshot = '';

  @override
  void initState() {
    super.initState();
    _pageToDataStopwatch = Stopwatch()..start();
    _pageToFirstImagesStopwatch = Stopwatch()..start();
    AppLogger.info('Nav',
        'Entrando a PlayersListPage @ ${DateTime.now().toIso8601String()}');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetPerfTracking() {
    _loggedPlayersDataReady = false;
    _loggedFirstTenImages = false;
    _firstRenderedImagePlayers.clear();
    _itemBuildCountByPlayerId.clear();
    _pageToDataStopwatch = Stopwatch()..start();
    _pageToFirstImagesStopwatch = Stopwatch()..start();
  }

  List<Player> _applyFilters(List<Player> source) {
    final query = _searchController.text.trim().toLowerCase();

    return source.where((player) {
      final matchesActive = !_onlyActive || player.isActive;
      if (!matchesActive) return false;

      if (query.isEmpty) return true;

      final fullName = '${player.firstName} ${player.lastName}'.toLowerCase();
      return fullName.contains(query) ||
          player.jerseyNumber.toString().contains(query);
    }).toList();
  }

  String _playerListPhotoPath(Player player) {
    // ignore: deprecated_member_use_from_same_package
    final url = player.photoThumbUrl ?? player.photoUrl;
    return (url ?? '').trim();
  }

  void _refreshPlayersProviders(String seasonId) {
    ref.invalidate(playersByActiveSeasonProvider);
    ref.invalidate(playersBySeasonProvider(seasonId));
    ref.invalidate(activeSeasonPlayersBundleProvider);
  }

  Future<bool> _handleSwipeAction({
    required DismissDirection direction,
    required Player player,
    required String seasonId,
    required bool canWrite,
  }) async {
    if (!canWrite) return false;

    if (direction == DismissDirection.startToEnd) {
      if (player.id == null || !mounted) return false;
      context.push('/players/${player.id}/edit');
      return false;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Eliminar jugador'),
            content: Text(
              '¿Seguro que deseas eliminar a ${player.firstName} ${player.lastName}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('No'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Sí, eliminar'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || player.id == null) return false;

    await ref.read(playersRepoProvider).deletePlayer(player.id!);
    _refreshPlayersProviders(seasonId);
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Jugador eliminado')),
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final playersBundleAsync = ref.watch(activeSeasonPlayersBundleProvider);

    return AppScaffold(
      title: AppStrings.players,
      selectedNavIndex: 0,
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'combine_rankings') {
              context.push('/combine-rankings');
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'combine_rankings',
              child: Text(AppStrings.combineRankings),
            ),
          ],
        ),
      ],
      body: WatermarkedBody(
        child: profileAsync.when(
          data: (profile) {
            final canWrite = profile?.canWriteGeneral ?? false;

            return playersBundleAsync.when(
              data: (bundle) {
                final season = bundle.season;
                if (season == null) {
                  return const EmptyState(
                    title: 'Sin temporada activa',
                    message:
                        'Selecciona una temporada activa en /season para listar jugadores.',
                    icon: Icons.calendar_month_outlined,
                  );
                }

                final players = bundle.players;
                if (!_loggedPlayersDataReady) {
                  _loggedPlayersDataReady = true;
                  _pageToDataStopwatch.stop();
                  AppLogger.perf(
                    'PlayersList.timeToPlayersData',
                    elapsed: _pageToDataStopwatch.elapsed,
                    detail: 'players=${players.length} season=${season.id}',
                  );
                }
                final filtered = _applyFilters(players);
                final topPhotoPaths = filtered
                    .map(_playerListPhotoPath)
                    .where((path) => path.trim().isNotEmpty)
                    .take(_precacheCount)
                    .toList();
                final precacheSnapshot = topPhotoPaths.join('|');
                if (precacheSnapshot.isNotEmpty &&
                    precacheSnapshot != _lastPrecacheSnapshot) {
                  _lastPrecacheSnapshot = precacheSnapshot;
                }
                final targetImageRenderCount = filtered
                    .where((p) => _playerListPhotoPath(p).trim().isNotEmpty)
                    .length
                    .clamp(0, 10);
                if (!_loggedFirstTenImages && targetImageRenderCount == 0) {
                  _loggedFirstTenImages = true;
                  _pageToFirstImagesStopwatch.stop();
                  AppLogger.perf(
                    'PlayersList.timeToFirst10Images',
                    elapsed: _pageToFirstImagesStopwatch.elapsed,
                    detail: 'sin fotos para renderizar',
                  );
                }
                final totalPlayers = players.length;
                final activePlayers = players.where((p) => p.isActive).length;
                final showingPlayers = filtered.length;
                final snapshot = players
                    .map((p) =>
                        '${p.id}:${p.photoThumbPath ?? p.photoPath ?? '-'}')
                    .join('|');
                if (snapshot != _lastPhotoSnapshotLog) {
                  _lastPhotoSnapshotLog = snapshot;
                  AppLogger.info(
                    'PlayersList.photoUrl',
                    'total=${players.length} paths=${players.map((p) => '${p.id}:${_playerListPhotoPath(p)}').join(', ')}',
                  );
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final compact = constraints.maxWidth < 900;
                              final actions = Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      _resetPerfTracking();
                                      ref.invalidate(
                                          playersByActiveSeasonProvider);
                                      ref.invalidate(
                                          playersBySeasonProvider(season.id));
                                      ref.invalidate(
                                          activeSeasonPlayersBundleProvider);
                                    },
                                    icon: const Icon(Icons.refresh_outlined),
                                    label: const Text('Refrescar'),
                                  ),
                                  FilledButton.icon(
                                    onPressed: canWrite
                                        ? () => context.push('/players/new')
                                        : null,
                                    icon: const Icon(Icons.person_add_alt_1),
                                    label: const Text('Agregar'),
                                  ),
                                ],
                              );
                              if (compact) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Temporada activa: ${season.name}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    actions,
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Temporada activa: ${season.name}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ),
                                  Flexible(child: actions),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'Buscar por nombre o # jersey',
                            ),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _onlyActive,
                            title: const Text('Mostrar solo activos'),
                            onChanged: (value) =>
                                setState(() => _onlyActive = value),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              children: [
                                Text(
                                  'Jugadores: $totalPlayers',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  'Activos: $activePlayers',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  'Mostrando: $showingPlayers',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? const EmptyState(
                              title: 'Sin resultados',
                              message:
                                  'No hay jugadores que coincidan con el filtro.',
                              icon: Icons.groups_outlined,
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemBuilder: (context, index) {
                                final player = filtered[index];
                                final playerKey =
                                    (player.id ?? 'idx_$index').trim();
                                final nextBuildCount =
                                    (_itemBuildCountByPlayerId[playerKey] ??
                                            0) +
                                        1;
                                _itemBuildCountByPlayerId[playerKey] =
                                    nextBuildCount;
                                AppLogger.info(
                                  'PlayersList.itemBuilder',
                                  'playerId=$playerKey rebuild=$nextBuildCount index=$index',
                                );
                                final photoPath = _playerListPhotoPath(player);
                                return Dismissible(
                                  key: ValueKey('player-swipe-$playerKey'),
                                  direction: canWrite
                                      ? DismissDirection.horizontal
                                      : DismissDirection.none,
                                  confirmDismiss: (direction) =>
                                      _handleSwipeAction(
                                    direction: direction,
                                    player: player,
                                    seasonId: season.id,
                                    canWrite: canWrite,
                                  ),
                                  background: Container(
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20),
                                    color: Colors.blueGrey.shade700,
                                    child: const Row(
                                      children: [
                                        Icon(Icons.edit_outlined,
                                            color: Colors.white),
                                        SizedBox(width: 8),
                                        Text(
                                          'Editar',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  secondaryBackground: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20),
                                    color: Colors.red.shade700,
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Icon(Icons.delete_outline,
                                            color: Colors.white),
                                        SizedBox(width: 8),
                                        Text(
                                          'Eliminar',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  child: Card(
                                    child: ListTile(
                                      onTap: () =>
                                          context.push('/players/${player.id}'),
                                      leading: _PlayerListAvatar(
                                        photoPath: photoPath,
                                        initials: player.initials,
                                        onFirstFrame: () {
                                          if (_loggedFirstTenImages ||
                                              !_firstRenderedImagePlayers
                                                  .add(playerKey)) {
                                            return;
                                          }
                                          final count =
                                              _firstRenderedImagePlayers.length;
                                          AppLogger.info(
                                            'PlayersList.imageFrame',
                                            'playerId=$playerKey count=$count',
                                          );
                                          if (count >= targetImageRenderCount) {
                                            _loggedFirstTenImages = true;
                                            _pageToFirstImagesStopwatch.stop();
                                            AppLogger.perf(
                                              'PlayersList.timeToFirst10Images',
                                              elapsed:
                                                  _pageToFirstImagesStopwatch
                                                      .elapsed,
                                              detail:
                                                  'count=$count target=$targetImageRenderCount',
                                            );
                                          }
                                        },
                                        onImageError: (error) {
                                          if (error
                                              is NetworkImageLoadException) {
                                            AppLogger.info(
                                              'PlayersList.image',
                                              'status=${error.statusCode} url=${error.uri}',
                                            );
                                          } else {
                                            AppLogger.info(
                                              'PlayersList.image',
                                              'error=$error path=$photoPath',
                                            );
                                          }
                                        },
                                      ),
                                      title: Text(
                                          '${player.firstName} ${player.lastName}'),
                                      subtitle: Text(
                                        '#${player.jerseyNumber} • ${player.position ?? 'Sin posicion'}${player.age != null ? ' • ${player.age} anos' : ''}${player.jerseySize != null ? ' • Talla ${player.jerseySize}' : ''}${player.uniformGender != null ? ' • ${player.uniformGender}' : ''} • ${player.isActive ? 'Activo' : 'Inactivo'}',
                                      ),
                                      trailing: IconButton(
                                        onPressed: canWrite
                                            ? () async {
                                                await ref
                                                    .read(playersRepoProvider)
                                                    .setPlayerActive(player.id!,
                                                        !player.isActive);
                                                _refreshPlayersProviders(
                                                    season.id);
                                              }
                                            : null,
                                        icon: Icon(
                                          player.isActive
                                              ? Icons.toggle_on_outlined
                                              : Icons.toggle_off_outlined,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemCount: filtered.length,
                            ),
                    ),
                  ],
                );
              },
              loading: () => const Loading(message: 'Cargando jugadores...'),
              error: (error, stack) => Center(child: Text('Error: $error')),
            );
          },
          loading: () => const Loading(message: 'Cargando permisos...'),
          error: (error, stack) => Center(child: Text('Error: $error')),
        ),
      ),
    );
  }
}

class _PlayerListAvatar extends ConsumerWidget {
  const _PlayerListAvatar({
    required this.photoPath,
    required this.initials,
    required this.onFirstFrame,
    required this.onImageError,
  });

  final String photoPath;
  final String initials;
  final VoidCallback onFirstFrame;
  final ValueChanged<Object> onImageError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const avatarSize = 40.0;
    final signedPhotoAsync = ref.watch(playerPhotoSignedUrlProvider(photoPath));
    final signedPhotoUrl = signedPhotoAsync.valueOrNull ?? '';
    final showNetwork = signedPhotoUrl.trim().isNotEmpty;

    return RepaintBoundary(
      child: SizedBox(
        width: avatarSize,
        height: avatarSize,
        child: CircleAvatar(
          child: ClipOval(
            child: SizedBox.expand(
              child: showNetwork
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        _AvatarPlaceholder(initials: initials),
                        Image.network(
                          signedPhotoUrl,
                          key: ValueKey(signedPhotoUrl),
                          gaplessPlayback: true,
                          fit: BoxFit.cover,
                          cacheWidth: 160,
                          cacheHeight: 160,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) {
                              onFirstFrame();
                              return child;
                            }
                            final total = progress.expectedTotalBytes;
                            final value = total != null && total > 0
                                ? progress.cumulativeBytesLoaded / total
                                : null;
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                _AvatarPlaceholder(initials: initials),
                                Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      value: value,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                          errorBuilder: (_, error, ___) {
                            onImageError(error);
                            return _AvatarPlaceholder(initials: initials);
                          },
                        ),
                      ],
                    )
                  : _AvatarPlaceholder(initials: initials),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Text(
          initials,
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ),
    );
  }
}
