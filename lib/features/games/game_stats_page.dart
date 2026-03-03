import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/providers/auth_providers.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading.dart';
import 'providers/game_plays_provider.dart';

typedef StatRow = ({String label, num value, String display});

List<StatRow> sortStatRowsByValue(List<StatRow> rows) {
  final sorted = [...rows]..sort((a, b) => b.value.compareTo(a.value));
  return sorted;
}

class GameStatsPage extends ConsumerWidget {
  const GameStatsPage({
    super.key,
    required this.gameId,
  });

  final String gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    if (profileAsync.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Estadísticas')),
        body: const Loading(message: 'Validando permisos...'),
      );
    }
    if (!(profileAsync.valueOrNull?.canWriteGeneral ?? false)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Estadísticas')),
        body: const EmptyState(
          title: 'No tienes permisos para ver jugadas',
          message: 'Solicita acceso de coach o super_admin.',
          icon: Icons.lock_outline,
        ),
      );
    }

    final playsAsync = ref.watch(gamePlaybookControllerProvider(gameId));
    return Scaffold(
      appBar: AppBar(title: const Text('Estadísticas')),
      body: playsAsync.when(
        data: (plays) {
          if (plays.isEmpty) {
            return const EmptyState(
              title: 'Sin jugadas',
              message: 'No hay jugadas registradas para calcular estadísticas.',
              icon: Icons.query_stats_outlined,
            );
          }

          final stats = buildGamePlayStats(plays);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatsBlock(
                title: 'QB completados / intentos',
                rows: _mergeTwo(stats.qbCompletions, stats.qbAttempts),
              ),
              _StatsBlock(
                title: 'Recepciones / Targets / Drops',
                rows: _mergeThree(stats.receptions, stats.targets, stats.drops),
              ),
              _StatsBlock(
                title: 'Yardas por recepción',
                rows: _fromNumericMap(stats.receivingYards),
              ),
              _StatsBlock(
                title: 'Intercepciones defensivas',
                rows: _fromNumericMap(stats.defInterceptions),
              ),
              _StatsBlock(
                title: 'Flags/Tackles',
                rows: _fromNumericMap(stats.tackleFlags),
              ),
              _StatsBlock(
                title: 'Sacks / Pressure',
                rows: _fromNumericMap(stats.sacks),
              ),
            ],
          );
        },
        loading: () => const Loading(message: 'Calculando estadísticas...'),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }
}

class _StatsBlock extends StatelessWidget {
  const _StatsBlock({required this.title, required this.rows});

  final String title;
  final List<StatRow> rows;

  @override
  Widget build(BuildContext context) {
    final entries = sortStatRowsByValue(rows);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              const Text('Sin datos')
            else
              ...entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('${e.label}: ${e.display}'),
                  )),
          ],
        ),
      ),
    );
  }
}

List<StatRow> _mergeTwo(Map<String, int> a, Map<String, int> b) {
  final keys = <String>{...a.keys, ...b.keys};
  final out = <StatRow>[];
  for (final k in keys) {
    final first = a[k] ?? 0;
    final second = b[k] ?? 0;
    out.add((label: k, value: first, display: '$first/$second'));
  }
  return out;
}

List<StatRow> _mergeThree(
    Map<String, int> a, Map<String, int> b, Map<String, int> c) {
  final keys = <String>{...a.keys, ...b.keys, ...c.keys};
  final out = <StatRow>[];
  for (final k in keys) {
    final first = a[k] ?? 0;
    final second = b[k] ?? 0;
    final third = c[k] ?? 0;
    out.add((label: k, value: first, display: '$first/$second/$third'));
  }
  return out;
}

List<StatRow> _fromNumericMap(Map<String, int> values) {
  return values.entries
      .map((entry) =>
          (label: entry.key, value: entry.value, display: '${entry.value}'))
      .toList();
}
