import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/providers/auth_providers.dart';
import '../../shared/widgets/loading.dart';
import 'providers/player_photo_providers.dart';
import 'providers/players_providers.dart';
import 'widgets/metric_form_sheet.dart';

@Deprecated(
  'Pantalla legacy no usada por rutas actuales. TODO(tech-debt): eliminar '
  'PlayerDetailPage y metric_form_sheet cuando termine migracion a PlayerProfilePage.',
)
class PlayerDetailPage extends ConsumerWidget {
  const PlayerDetailPage({
    super.key,
    required this.playerId,
  });

  final String playerId;

  Future<void> _showMetricSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return MetricFormSheet(
          playerId: playerId,
          onSubmit: (metric) async {
            await ref.read(playersRepoProvider).addMetric(playerId, metric);
            ref.invalidate(playerMetricsProvider(playerId));
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerAsync = ref.watch(playerByIdProvider(playerId));
    final metricsAsync = ref.watch(playerMetricsProvider(playerId));
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle jugador')),
      body: playerAsync.when(
        data: (player) {
          if (player == null) {
            return const Center(child: Text('Jugador no encontrado.'));
          }
          final signedPhotoAsync =
              ref.watch(playerPhotoSignedUrlProvider(player.photoPath));
          final signedPhotoUrl = signedPhotoAsync.valueOrNull;

          return profileAsync.when(
            data: (profile) {
              final canWrite = profile?.canWriteGeneral ?? false;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: ListTile(
                      leading: (signedPhotoUrl ?? '').trim().isNotEmpty
                          ? CircleAvatar(
                              child: ClipOval(
                                child: SizedBox.expand(
                                  child: Image.network(
                                    signedPhotoUrl!,
                                    key: ValueKey(signedPhotoUrl),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        Center(child: Text(player.initials)),
                                  ),
                                ),
                              ),
                            )
                          : CircleAvatar(child: Text(player.initials)),
                      title: Text('${player.firstName} ${player.lastName}'),
                      subtitle: Text(
                          '#${player.jerseyNumber} • ${player.position ?? 'Sin posicion'}'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: canWrite
                            ? () => context.push('/players/$playerId/edit')
                            : null,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Editar'),
                      ),
                      OutlinedButton.icon(
                        onPressed: canWrite
                            ? () => _showMetricSheet(context, ref)
                            : null,
                        icon: const Icon(Icons.add_chart_outlined),
                        label: const Text('Agregar medicion'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Metricas',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  metricsAsync.when(
                    data: (metrics) {
                      if (metrics.isEmpty) {
                        return const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Sin mediciones registradas.'),
                          ),
                        );
                      }

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Fecha')),
                            DataColumn(label: Text('40yd')),
                            DataColumn(label: Text('10yd')),
                            DataColumn(label: Text('5-10-5')),
                            DataColumn(label: Text('Vertical cm')),
                          ],
                          rows: metrics
                              .map(
                                (m) => DataRow(cells: [
                                  DataCell(Text(m.measuredOn
                                      .toIso8601String()
                                      .split('T')
                                      .first)),
                                  DataCell(Text(
                                      m.fortyYdSeconds?.toString() ?? '-')),
                                  DataCell(
                                      Text(m.tenYdSplit?.toString() ?? '-')),
                                  DataCell(
                                      Text(m.shuttle5105?.toString() ?? '-')),
                                  DataCell(Text(
                                      m.verticalJumpCm?.toString() ?? '-')),
                                ]),
                              )
                              .toList(),
                        ),
                      );
                    },
                    loading: () =>
                        const Loading(message: 'Cargando metricas...'),
                    error: (error, stack) => Text('Error: $error'),
                  ),
                ],
              );
            },
            loading: () => const Loading(message: 'Cargando permisos...'),
            error: (error, stack) => Text('Error: $error'),
          );
        },
        loading: () => const Loading(message: 'Cargando jugador...'),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
