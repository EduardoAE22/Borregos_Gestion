import 'package:borregos_gestion/core/utils/formatters.dart';
import 'package:borregos_gestion/features/payments/data/payments_repo.dart';
import 'package:borregos_gestion/features/payments/domain/uniform_campaign.dart';
import 'package:borregos_gestion/features/payments/domain/weekly_summary.dart';
import 'package:borregos_gestion/features/payments/providers/payments_providers.dart';
import 'package:borregos_gestion/features/payments/providers/uniform_campaigns_providers.dart';
import 'package:borregos_gestion/features/seasons/providers/seasons_providers.dart';
import 'package:borregos_gestion/features/settings/data/settings_repo.dart';
import 'package:borregos_gestion/shared/widgets/empty_state.dart';
import 'package:borregos_gestion/shared/widgets/loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PaymentsSummaryMode {
  training,
  uniform,
}

class WeeklySummaryPage extends ConsumerStatefulWidget {
  const WeeklySummaryPage({
    super.key,
    this.initialWeekStart,
    this.mode = PaymentsSummaryMode.training,
    this.initialCampaignId,
  });

  final DateTime? initialWeekStart;
  final PaymentsSummaryMode mode;
  final String? initialCampaignId;

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
      appBar: AppBar(
        title: Text(
          widget.mode == PaymentsSummaryMode.training
              ? 'Resumen semanal'
              : 'Resumen uniforme',
        ),
      ),
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

          if (widget.mode == PaymentsSummaryMode.uniform) {
            final campaignsAsync =
                ref.watch(uniformCampaignsByActiveSeasonProvider);
            return campaignsAsync.when(
              data: (campaigns) {
                if (campaigns.isEmpty) {
                  return const EmptyState(
                    title: 'Sin campanas de uniforme',
                    message:
                        'Crea una campana para ver el resumen de uniforme.',
                    icon: Icons.checkroom_outlined,
                  );
                }
                final selectedCampaign =
                    campaigns.cast<UniformCampaign?>().firstWhere(
                          (campaign) =>
                              campaign?.id == widget.initialCampaignId,
                          orElse: () => campaigns.first,
                        )!;
                final summariesAsync = ref.watch(
                  uniformCampaignPlayerSummariesProvider(selectedCampaign),
                );
                return summariesAsync.when(
                  data: (rows) {
                    final complete = rows
                        .where((row) =>
                            row.state == UniformCampaignPaymentState.complete)
                        .length;
                    final partial = rows
                        .where((row) =>
                            row.state == UniformCampaignPaymentState.partial)
                        .length;
                    final pending = rows
                        .where((row) =>
                            row.state == UniformCampaignPaymentState.unpaid)
                        .length;
                    final totalPaid = rows.fold<double>(
                      0,
                      (sum, row) => sum + row.totalPaid,
                    );

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(selectedCampaign.name),
                          subtitle: Text('Temporada: ${season.name}'),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _MetricCard(
                              label: 'Total pagado',
                              value: AppFormatters.money(totalPaid),
                            ),
                            _MetricCard(
                              label: 'Pago completo',
                              value: '$complete/${rows.length}',
                            ),
                            _MetricCard(
                              label: 'Abonaron',
                              value: '$partial',
                            ),
                            _MetricCard(
                              label: 'Pendientes',
                              value: '$pending',
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Jugadores',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        ...rows.map(
                          (row) {
                            final displayName = (row.player.jerseyName ?? '')
                                    .trim()
                                    .isNotEmpty
                                ? row.player.jerseyName!.trim()
                                : '${row.player.firstName} ${row.player.lastName}'
                                    .trim();
                            final status = switch (row.state) {
                              UniformCampaignPaymentState.complete => 'PAGADO',
                              UniformCampaignPaymentState.partial => 'ABONO',
                              UniformCampaignPaymentState.unpaid => 'PENDIENTE',
                            };
                            return Card(
                              child: ListTile(
                                title: Text(
                                    '#${row.player.jerseyNumber} $displayName'),
                                subtitle: Text(
                                  'Pagado: ${AppFormatters.money(row.totalPaid)} · '
                                  'Falta: ${AppFormatters.money(row.remaining)}',
                                ),
                                trailing: Chip(label: Text(status)),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                  loading: () =>
                      const Loading(message: 'Calculando resumen...'),
                  error: (error, stack) => Center(child: Text('Error: $error')),
                );
              },
              loading: () => const Loading(message: 'Cargando campanas...'),
              error: (error, stack) => Center(child: Text('Error: $error')),
            );
          }

          final summaryAsync = ref.watch(
            weeklySummaryProvider((seasonId: season.id, weekStart: _weekStart)),
          );

          return summaryAsync.when(
            data: (summary) {
              final debtors = summary.byPlayer
                  .where((p) => p.paymentState == 'pending')
                  .toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title:
                        Text('Semana desde ${AppFormatters.date(_weekStart)}'),
                    subtitle: Text('Temporada: ${season.name}'),
                    trailing: TextButton(
                      onPressed: _pickWeek,
                      child: const Text('Cambiar'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MetricCard(
                        label: 'Total pagado',
                        value: AppFormatters.money(summary.totalPaid),
                      ),
                      _MetricCard(
                        label: 'Pagados',
                        value: '${summary.paidPlayers}/${summary.totalPlayers}',
                      ),
                      _MetricCard(
                        label: 'Abono',
                        value: summary.partialPlayers.toString(),
                      ),
                      _MetricCard(
                        label: 'Pendientes',
                        value: summary.pendingPlayers.toString(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('Pendientes',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (debtors.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No hay pendientes para esta semana.'),
                      ),
                    )
                  else
                    ...debtors.map(
                      (PlayerWeeklySummary d) => Card(
                        child: ListTile(
                          title: Text(d.playerName),
                          subtitle: Text(
                            'Pagado: ${AppFormatters.money(d.amountPaidThisWeek)} · '
                            'Falta: ${AppFormatters.money((d.requiredAmount - d.amountPaidThisWeek).clamp(0, d.requiredAmount))}',
                          ),
                          trailing: const Chip(label: Text('Pendiente')),
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
                          'Pagado: ${AppFormatters.money(p.amountPaidThisWeek)} · '
                          'Falta: ${AppFormatters.money((p.requiredAmount - p.amountPaidThisWeek).clamp(0, p.requiredAmount))}',
                        ),
                        trailing: Chip(
                          label: Text(
                            switch (p.paymentState) {
                              'paid' => 'Pagado',
                              'partial' => 'Abono',
                              _ => 'Pendiente',
                            },
                          ),
                        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
