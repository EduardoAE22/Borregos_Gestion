import 'package:borregos_gestion/core/utils/formatters.dart';
import 'package:borregos_gestion/features/payments/data/payments_repo.dart';
import 'package:borregos_gestion/features/payments/domain/weekly_summary.dart';
import 'package:borregos_gestion/features/payments/providers/payments_providers.dart';
import 'package:borregos_gestion/features/seasons/providers/seasons_providers.dart';
import 'package:borregos_gestion/features/settings/data/settings_repo.dart';
import 'package:borregos_gestion/shared/widgets/empty_state.dart';
import 'package:borregos_gestion/shared/widgets/loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WeeklySummaryPage extends ConsumerStatefulWidget {
  const WeeklySummaryPage({
    super.key,
    this.initialWeekStart,
  });

  final DateTime? initialWeekStart;

  @override
  ConsumerState<WeeklySummaryPage> createState() => _WeeklySummaryPageState();
}

class _WeeklySummaryPageState extends ConsumerState<WeeklySummaryPage> {
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _weekStart = PaymentsRepo.mondayOfWeek(
      widget.initialWeekStart ?? DateTime.now(),
    );
  }

  Future<void> _pickWeek() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _weekStart,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _weekStart = PaymentsRepo.mondayOfWeek(picked));
  }

  @override
  Widget build(BuildContext context) {
    final seasonAsync = ref.watch(activeSeasonProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Resumen semanal')),
      body: seasonAsync.when(
        data: (season) {
          if (season == null) {
            return const EmptyState(
              title: 'Sin temporada activa',
              message:
                  'Selecciona una temporada activa en /season para ver resumenes.',
              icon: Icons.calendar_month_outlined,
            );
          }

          final summaryAsync = ref.watch(
            weeklySummaryProvider((seasonId: season.id, weekStart: _weekStart)),
          );

          return summaryAsync.when(
            data: (summary) {
              final debtors = summary.byPlayer.where((p) => p.pending).toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title:
                        Text('Semana desde ${AppFormatters.date(_weekStart)}'),
                    subtitle: Text('Temporada: ${season.name}'),
                    trailing: TextButton(
                        onPressed: _pickWeek, child: const Text('Cambiar')),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          label: 'Total pagado',
                          value: AppFormatters.money(summary.totalPaid),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MetricCard(
                          label: 'Pagaron',
                          value:
                              '${summary.paidPlayers}/${summary.totalPlayers}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MetricCard(
                          label: 'Deudores',
                          value: summary.pendingPlayers.toString(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('Deudores',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (debtors.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No hay deudores para esta semana.'),
                      ),
                    )
                  else
                    ...debtors.map(
                      (PlayerWeeklySummary d) => Card(
                        child: ListTile(
                          title: Text(d.playerName),
                          subtitle: Text(
                            d.paidThisWeek
                                ? 'Pagado: ${AppFormatters.money(d.amountPaidThisWeek)}'
                                : 'Sin pago de Semana en esta semana',
                          ),
                          trailing: d.pending
                              ? const Chip(label: Text('Pendiente'))
                              : Text(AppFormatters.money(d.amountPaidThisWeek)),
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  Text('Todos', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...summary.byPlayer.map(
                    (p) => Card(
                      child: ListTile(
                        title: Text(p.playerName),
                        subtitle: Text(
                          p.paidThisWeek
                              ? 'Pagado: ${AppFormatters.money(p.amountPaidThisWeek)}'
                              : 'Sin pago',
                        ),
                        trailing: p.pending
                            ? const Chip(label: Text('Pendiente'))
                            : const Chip(label: Text('Pagado')),
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Loading(message: 'Calculando resumen...'),
            error: (error, stack) {
              if (error is InvalidWeeklyConceptSettingException ||
                  error is WeeklyConceptNotConfiguredException) {
                return const EmptyState(
                  title: 'Configura el concepto semanal',
                  message: 'Configura el concepto semanal en Settings.',
                  icon: Icons.settings_outlined,
                );
              }
              return Center(child: Text('Error: $error'));
            },
          );
        },
        loading: () => const Loading(message: 'Cargando temporada...'),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
