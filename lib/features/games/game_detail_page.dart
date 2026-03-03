import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/providers/auth_providers.dart';
import '../../shared/widgets/loading.dart';
import 'domain/game.dart';
import 'providers/games_providers.dart';

class GameDetailPage extends ConsumerWidget {
  const GameDetailPage({
    super.key,
    required this.gameId,
  });

  final String gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameAsync = ref.watch(gameByIdProvider(gameId));
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle partido')),
      body: gameAsync.when(
        data: (game) {
          if (game == null) {
            return const Center(child: Text('Partido no encontrado.'));
          }

          return profileAsync.when(
            data: (profile) {
              final canWrite = profile?.canWriteGeneral ?? false;
              final isSeasonGame =
                  game.seasonId != null && game.seasonId!.trim().isNotEmpty;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.sports_football_outlined),
                      title: Text('vs ${game.opponent}'),
                      subtitle: Text(
                        '${game.gameDate.toIso8601String().split('T').first} • ${game.location ?? 'Sin sede'} • ${gameTypeLabel(game.gameType)}',
                      ),
                      trailing: Text('${game.ourScore} - ${game.oppScore}'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (isSeasonGame) ...[
                    FilledButton.icon(
                      onPressed: canWrite
                          ? () => context.push('/games/$gameId/stats/qb')
                          : null,
                      icon: const Icon(Icons.sports_football),
                      label: const Text('Capturar stats QB'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: canWrite
                          ? () => context.push('/games/$gameId/stats/skill')
                          : null,
                      icon: const Icon(Icons.flash_on_outlined),
                      label: const Text('Capturar stats Skill'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: canWrite
                          ? () => context.push('/games/$gameId/stats/def')
                          : null,
                      icon: const Icon(Icons.shield_outlined),
                      label: const Text('Capturar stats Defensa'),
                    ),
                    const SizedBox(height: 8),
                  ] else ...[
                    const Text(
                        'Partido global: los stats de temporada no aplican.'),
                    const SizedBox(height: 8),
                  ],
                  FilledButton.icon(
                    onPressed: canWrite
                        ? () => context.push('/games/$gameId/capture')
                        : null,
                    icon: const Icon(Icons.playlist_add_check_outlined),
                    label: const Text('Registrar jugadas'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/games/$gameId/play-stats'),
                    icon: const Icon(Icons.query_stats_outlined),
                    label: const Text('Estadísticas'),
                  ),
                  if (!canWrite) ...[
                    const SizedBox(height: 8),
                    const Text('Modo solo lectura para este rol.'),
                  ],
                ],
              );
            },
            loading: () => const Loading(message: 'Cargando permisos...'),
            error: (error, stack) => Center(child: Text('Error: $error')),
          );
        },
        loading: () => const Loading(message: 'Cargando partido...'),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
