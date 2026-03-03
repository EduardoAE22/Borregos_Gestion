import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/app_strings.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/open_external_url.dart';
import '../../core/theme/brand.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/background_watermark.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading.dart';
import '../auth/providers/auth_providers.dart';
import '../players/domain/player.dart';
import '../seasons/providers/seasons_providers.dart';
import 'domain/payment.dart';
import 'domain/uniform_campaign.dart';
import 'domain/weekly_payments_board.dart';
import 'providers/payments_providers.dart';
import 'providers/uniform_campaigns_providers.dart';
import 'widgets/payment_form_sheet.dart';
import 'widgets/uniform_campaign_form_sheet.dart';

enum _PaymentsBoardFilter { all, pending, paid }

enum _PaymentsBoardMode { training, uniform }

class PaymentsPage extends ConsumerStatefulWidget {
  const PaymentsPage({super.key});

  @override
  ConsumerState<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends ConsumerState<PaymentsPage> {
  static const Duration _signedUrlTtl = Duration(days: 6);

  late DateTime _selectedWeekStart;
  final _searchController = TextEditingController();
  final Map<String, ({String url, DateTime cachedAt})> _signedUrlCache =
      <String, ({String url, DateTime cachedAt})>{};
  final Set<String> _loadingReceiptPaths = <String>{};
  _PaymentsBoardFilter _filter = _PaymentsBoardFilter.all;
  _PaymentsBoardMode _mode = _PaymentsBoardMode.training;
  String? _selectedUniformCampaignId;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedWeekStart = getWeekStartMonday(DateTime.now());
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  DateTime get _selectedWeekEnd => getWeekEndSunday(_selectedWeekStart);

  void _shiftWeek(int days) {
    setState(() =>
        _selectedWeekStart = _selectedWeekStart.add(Duration(days: days)));
  }

  void _resetCurrentWeek() {
    setState(() => _selectedWeekStart = getWeekStartMonday(DateTime.now()));
  }

  Future<void> _pickWeek() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedWeekStart,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _selectedWeekStart = getWeekStartMonday(picked));
  }

  void _invalidatePayments() {
    ref.invalidate(weeklyPaymentsBySeasonProvider(_selectedWeekStart));
    ref.invalidate(
      weeklyPaymentsByCategoryProvider(
        (weekStart: _selectedWeekStart, category: PaymentCategory.training),
      ),
    );
    ref.invalidate(weeklyPaymentStatusByPlayerProvider(_selectedWeekStart));
    ref.invalidate(weeklyDebtCountsByPlayerProvider(_selectedWeekStart));
    ref.invalidate(weeklyPaymentsDashboardProvider(_selectedWeekStart));
    ref.invalidate(paymentsByCategoryProvider(PaymentCategory.uniform));
    ref.invalidate(uniformCampaignsByActiveSeasonProvider);
    if (_selectedUniformCampaignId != null) {
      ref.invalidate(
        uniformPaymentsForCampaignProvider(_selectedUniformCampaignId!),
      );
    }
    ref.invalidate(paymentsByActiveSeasonProvider);
    ref.invalidate(weeklySummaryProvider);
  }

  Future<void> _openPaymentSheet(
    BuildContext context,
    String seasonId, {
    String? playerId,
    String? conceptId,
    PaymentRow? payment,
    bool isTraining = false,
    String? uniformCampaignId,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return PaymentFormSheet(
          seasonId: seasonId,
          initialPayment: payment,
          initialPlayerId: playerId,
          initialConceptId: conceptId,
          initialWeekStart: isTraining ? _selectedWeekStart : null,
          initialWeekEnd: isTraining ? _selectedWeekEnd : null,
          initialUniformCampaignId: uniformCampaignId,
          onSaved: _invalidatePayments,
        );
      },
    );
  }

  Future<void> _deletePaymentForCard(
    BuildContext context,
    String playerLabel,
    PaymentRow? payment,
    String paymentScopeLabel,
  ) async {
    if (payment == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar pago'),
        content: Text(
          '¿Eliminar pago de $playerLabel de $paymentScopeLabel?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sí'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(paymentsRepoProvider).deletePayment(payment.id);
    _invalidatePayments();
  }

  Future<void> _openUniformCampaignSheet(
    BuildContext context,
    String seasonId, {
    UniformCampaign? campaign,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => UniformCampaignFormSheet(
        seasonId: seasonId,
        initialCampaign: campaign,
        onSaved: _invalidatePayments,
      ),
    );
  }

  bool _isPdfReceipt(String receiptPath) {
    final lower = receiptPath.toLowerCase();
    return lower.split('?').first.endsWith('.pdf');
  }

  Future<void> _openPdfExternally(
      BuildContext context, String signedUrl) async {
    final ok = await openExternalUrl(signedUrl);
    if (!context.mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo abrir el PDF.')),
    );
  }

  Future<void> _showReceiptDialog(
      BuildContext context, String signedUrl) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  child: Image.network(
                    signedUrl,
                    key: ValueKey(signedUrl),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openReceipt(BuildContext context, String receiptPath) async {
    final isPdf = _isPdfReceipt(receiptPath);
    final cached = _signedUrlCache[receiptPath];
    if (cached != null &&
        DateTime.now().difference(cached.cachedAt) < _signedUrlTtl) {
      if (isPdf) {
        await _openPdfExternally(context, cached.url);
      } else {
        await _showReceiptDialog(context, cached.url);
      }
      return;
    }

    setState(() => _loadingReceiptPaths.add(receiptPath));
    try {
      final signedUrl = await ref
          .read(paymentsRepoProvider)
          .createReceiptSignedUrl(receiptPath);
      _signedUrlCache[receiptPath] = (url: signedUrl, cachedAt: DateTime.now());
      if (!mounted || !context.mounted) return;
      if (isPdf) {
        await _openPdfExternally(context, signedUrl);
      } else {
        await _showReceiptDialog(context, signedUrl);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingReceiptPaths.remove(receiptPath));
      }
    }
  }

  List<WeeklyPlayerPaymentCardData> _filterTrainingCards(
    List<WeeklyPlayerPaymentCardData> cards,
  ) {
    final searched = cards
        .where((card) => playerMatchesSearch(card.player, _searchQuery))
        .toList();

    return switch (_filter) {
      _PaymentsBoardFilter.all => searched,
      _PaymentsBoardFilter.pending => searched
          .where((card) => card.weekStatus.state != WeeklyPaymentState.paid)
          .toList(),
      _PaymentsBoardFilter.paid => searched
          .where((card) => card.weekStatus.state == WeeklyPaymentState.paid)
          .toList(),
    };
  }

  List<UniformCampaignPlayerSummary> _buildUniformCards({
    required List<UniformCampaignPlayerSummary> summaries,
  }) {
    final cards = summaries
        .where((card) => playerMatchesSearch(card.player, _searchQuery))
        .toList();

    return switch (_filter) {
      _PaymentsBoardFilter.all => cards,
      _PaymentsBoardFilter.pending => cards
          .where((card) => card.state != UniformCampaignPaymentState.complete)
          .toList(),
      _PaymentsBoardFilter.paid => cards
          .where((card) => card.state == UniformCampaignPaymentState.complete)
          .toList(),
    };
  }

  void _syncSelectedUniformCampaign(List<UniformCampaign> campaigns) {
    if (campaigns.isEmpty) {
      if (_selectedUniformCampaignId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _selectedUniformCampaignId = null);
          }
        });
      }
      return;
    }

    final exists = campaigns.any(
      (campaign) => campaign.id == _selectedUniformCampaignId,
    );
    if (_selectedUniformCampaignId == null || !exists) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _selectedUniformCampaignId = campaigns.first.id);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final seasonAsync = ref.watch(activeSeasonProvider);
    final playersAsync = ref.watch(activeSeasonActivePlayersProvider);
    final trainingDashboardAsync =
        ref.watch(weeklyPaymentsDashboardProvider(_selectedWeekStart));
    final uniformCampaignsAsync =
        ref.watch(uniformCampaignsByActiveSeasonProvider);

    return AppScaffold(
      title: AppStrings.payments,
      selectedNavIndex: 1,
      body: WatermarkedBody(
        child: profileAsync.when(
          data: (profile) {
            final canWritePayments = profile?.canWritePayments ?? false;

            return seasonAsync.when(
              data: (season) {
                if (season == null) {
                  return const EmptyState(
                    title: 'Sin temporada activa',
                    message:
                        'Selecciona una temporada activa en /season para gestionar pagos.',
                    icon: Icons.calendar_month_outlined,
                  );
                }

                if (playersAsync.isLoading ||
                    trainingDashboardAsync.isLoading ||
                    uniformCampaignsAsync.isLoading) {
                  return const Loading(message: 'Cargando pagos...');
                }

                final players = playersAsync.valueOrNull ?? const <Player>[];
                final trainingDashboard = trainingDashboardAsync.valueOrNull ??
                    const WeeklyPaymentsDashboardData(
                      players: <WeeklyPlayerPaymentCardData>[],
                      totalActivePlayers: 0,
                      paidPlayers: 0,
                      pendingPlayers: 0,
                      totalDebts: 0,
                    );
                final uniformCampaigns = uniformCampaignsAsync.valueOrNull ??
                    const <UniformCampaign>[];
                _syncSelectedUniformCampaign(uniformCampaigns);
                final selectedUniformCampaign =
                    uniformCampaigns.cast<UniformCampaign?>().firstWhere(
                          (campaign) =>
                              campaign?.id == _selectedUniformCampaignId,
                          orElse: () => uniformCampaigns.isEmpty
                              ? null
                              : uniformCampaigns.first,
                        );
                final trainingCards =
                    _filterTrainingCards(trainingDashboard.players);
                final uniformSummariesAsync = selectedUniformCampaign == null
                    ? const AsyncData<List<UniformCampaignPlayerSummary>>(
                        <UniformCampaignPlayerSummary>[],
                      )
                    : ref.watch(
                        uniformCampaignPlayerSummariesProvider(
                          selectedUniformCampaign,
                        ),
                      );
                if (_mode == _PaymentsBoardMode.uniform &&
                    uniformSummariesAsync.hasError) {
                  return Center(
                    child: Text(
                      'Error cargando campana: ${uniformSummariesAsync.error}',
                    ),
                  );
                }
                if (_mode == _PaymentsBoardMode.uniform &&
                    uniformSummariesAsync.isLoading) {
                  return const Loading(message: 'Cargando uniforme...');
                }
                final uniformCards = _buildUniformCards(
                  summaries: uniformSummariesAsync.valueOrNull ??
                      const <UniformCampaignPlayerSummary>[],
                );
                final uniformPaidPlayers = uniformCards
                    .where((card) =>
                        card.state == UniformCampaignPaymentState.complete)
                    .length;
                final uniformPendingPlayers = uniformCards
                    .where((card) =>
                        card.state != UniformCampaignPaymentState.complete)
                    .length;
                final uniformTotalPaid = uniformCards.fold<double>(
                  0,
                  (sum, card) => sum + card.totalPaid,
                );

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Temporada activa: ${season.name}',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () {
                                  final query = Uri(
                                    queryParameters: {
                                      'weekStart':
                                          _selectedWeekStart.toIso8601String(),
                                    },
                                  ).query;
                                  context
                                      .push('/payments/weekly-summary?$query');
                                },
                                icon: const Icon(Icons.summarize_outlined),
                                label: const Text('Resumen semanal'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SegmentedButton<_PaymentsBoardMode>(
                            segments: const [
                              ButtonSegment(
                                value: _PaymentsBoardMode.training,
                                label: Text('Entrenamiento'),
                              ),
                              ButtonSegment(
                                value: _PaymentsBoardMode.uniform,
                                label: Text('Uniforme'),
                              ),
                            ],
                            selected: {_mode},
                            onSelectionChanged: (selection) {
                              setState(() => _mode = selection.first);
                            },
                          ),
                          const SizedBox(height: 10),
                          if (_mode == _PaymentsBoardMode.training) ...[
                            _WeekSelector(
                              weekStart: _selectedWeekStart,
                              weekEnd: _selectedWeekEnd,
                              onPrevious: () => _shiftWeek(-7),
                              onCurrent: _resetCurrentWeek,
                              onNext: () => _shiftWeek(7),
                              onPickDate: _pickWeek,
                            ),
                            const SizedBox(height: 10),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    key: ValueKey(selectedUniformCampaign?.id),
                                    initialValue: selectedUniformCampaign?.id,
                                    decoration: const InputDecoration(
                                      labelText: 'Campana de uniforme',
                                    ),
                                    items: uniformCampaigns
                                        .map(
                                          (campaign) => DropdownMenuItem(
                                            value: campaign.id,
                                            child: Text(campaign.name),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: uniformCampaigns.isEmpty
                                        ? null
                                        : (value) => setState(
                                              () => _selectedUniformCampaignId =
                                                  value,
                                            ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: canWritePayments
                                      ? () => _openUniformCampaignSheet(
                                            context,
                                            season.id,
                                          )
                                      : null,
                                  icon: const Icon(Icons.add),
                                  label: Text(
                                    uniformCampaigns.isEmpty
                                        ? 'Crear uniforme'
                                        : 'Nueva campana',
                                  ),
                                ),
                                if (selectedUniformCampaign != null) ...[
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: canWritePayments
                                        ? () => _openUniformCampaignSheet(
                                              context,
                                              season.id,
                                              campaign: selectedUniformCampaign,
                                            )
                                        : null,
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('Editar'),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 10),
                          ],
                          TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              labelText:
                                  'Buscar jugador (apodo, nombre, apellido, #)',
                              prefixIcon: Icon(Icons.search),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _mode == _PaymentsBoardMode.training
                                ? [
                                    _MetricChip(
                                      label: 'Activos',
                                      value: trainingDashboard
                                          .totalActivePlayers
                                          .toString(),
                                    ),
                                    _MetricChip(
                                      label: 'Pagados esta semana',
                                      value: trainingDashboard.paidPlayers
                                          .toString(),
                                    ),
                                    _MetricChip(
                                      label: 'Pendientes esta semana',
                                      value: trainingDashboard.pendingPlayers
                                          .toString(),
                                    ),
                                    _MetricChip(
                                      label: 'Adeudos totales',
                                      value: trainingDashboard.totalDebts
                                          .toString(),
                                    ),
                                  ]
                                : [
                                    _MetricChip(
                                      label: 'Activos',
                                      value: players.length.toString(),
                                    ),
                                    _MetricChip(
                                      label: 'Con pago uniforme',
                                      value: uniformPaidPlayers.toString(),
                                    ),
                                    _MetricChip(
                                      label: 'Pendientes uniforme',
                                      value: uniformPendingPlayers.toString(),
                                    ),
                                    _MetricChip(
                                      label: 'Total pagado',
                                      value:
                                          AppFormatters.money(uniformTotalPaid),
                                    ),
                                  ],
                          ),
                          const SizedBox(height: 10),
                          SegmentedButton<_PaymentsBoardFilter>(
                            segments: const [
                              ButtonSegment(
                                value: _PaymentsBoardFilter.all,
                                label: Text('Todos'),
                              ),
                              ButtonSegment(
                                value: _PaymentsBoardFilter.pending,
                                label: Text('Pendientes'),
                              ),
                              ButtonSegment(
                                value: _PaymentsBoardFilter.paid,
                                label: Text('Pagados'),
                              ),
                            ],
                            selected: {_filter},
                            onSelectionChanged: (selection) {
                              setState(() => _filter = selection.first);
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _mode == _PaymentsBoardMode.training
                          ? trainingCards.isEmpty
                              ? const EmptyState(
                                  title: 'Sin resultados',
                                  message:
                                      'No hay jugadores activos para este filtro.',
                                  icon: Icons.payments_outlined,
                                )
                              : ListView.separated(
                                  padding:
                                      const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                  itemCount: trainingCards.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 6),
                                  itemBuilder: (context, index) {
                                    final item = trainingCards[index];
                                    final payment =
                                        item.weekStatus.currentPayment;
                                    final playerLabel =
                                        '${item.player.jerseyName?.trim().isNotEmpty == true ? item.player.jerseyName!.trim() : item.player.firstName} #${item.player.jerseyNumber}';

                                    return Dismissible(
                                      key: ValueKey(
                                          'training-${item.player.id}-${payment?.id ?? 'none'}'),
                                      confirmDismiss: (direction) async {
                                        if (direction ==
                                            DismissDirection.startToEnd) {
                                          await _openPaymentSheet(
                                            context,
                                            season.id,
                                            playerId: item.player.id,
                                            payment: payment,
                                            isTraining: true,
                                          );
                                          return false;
                                        }
                                        if (direction ==
                                            DismissDirection.endToStart) {
                                          await _deletePaymentForCard(
                                            context,
                                            playerLabel,
                                            payment,
                                            'la semana ${AppFormatters.date(payment?.weekStart ?? _selectedWeekStart)} - ${AppFormatters.date(payment?.weekEnd ?? _selectedWeekEnd)}',
                                          );
                                          return false;
                                        }
                                        return false;
                                      },
                                      background: _SwipeBackground(
                                        alignment: Alignment.centerLeft,
                                        color: Colors.blue.shade600,
                                        icon: Icons.edit_outlined,
                                        label: payment == null
                                            ? 'Registrar'
                                            : 'Editar',
                                      ),
                                      secondaryBackground: _SwipeBackground(
                                        alignment: Alignment.centerRight,
                                        color: Colors.red.shade600,
                                        icon: Icons.delete_outline,
                                        label: 'Eliminar',
                                      ),
                                      child: _TrainingPaymentCard(
                                        item: item,
                                        canWritePayments: canWritePayments,
                                        isLoadingReceipt:
                                            payment?.receiptUrl != null &&
                                                _loadingReceiptPaths.contains(
                                                  payment!.receiptUrl!,
                                                ),
                                        onRegisterOrEdit: canWritePayments
                                            ? () => _openPaymentSheet(
                                                  context,
                                                  season.id,
                                                  playerId: item.player.id,
                                                  payment: payment,
                                                  isTraining: true,
                                                )
                                            : null,
                                        onViewReceipt:
                                            payment?.receiptUrl == null
                                                ? null
                                                : () => _openReceipt(
                                                      context,
                                                      payment!.receiptUrl!,
                                                    ),
                                      ),
                                    );
                                  },
                                )
                          : uniformCampaigns.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const EmptyState(
                                        title: 'Sin campanas de uniforme',
                                        message:
                                            'Crea una campana para registrar abonos y pagos de uniforme.',
                                        icon: Icons.checkroom_outlined,
                                      ),
                                      const SizedBox(height: 12),
                                      if (canWritePayments)
                                        FilledButton.icon(
                                          onPressed: () =>
                                              _openUniformCampaignSheet(
                                            context,
                                            season.id,
                                          ),
                                          icon: const Icon(Icons.add),
                                          label: const Text('Crear uniforme'),
                                        ),
                                    ],
                                  ),
                                )
                              : uniformCards.isEmpty
                                  ? const EmptyState(
                                      title: 'Sin resultados',
                                      message:
                                          'No hay jugadores activos para este filtro.',
                                      icon: Icons.payments_outlined,
                                    )
                                  : ListView.separated(
                                      padding: const EdgeInsets.fromLTRB(
                                          12, 0, 12, 12),
                                      itemCount: uniformCards.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 6),
                                      itemBuilder: (context, index) {
                                        final item = uniformCards[index];
                                        final payment = item.latestPayment;
                                        final playerLabel =
                                            '${item.player.jerseyName?.trim().isNotEmpty == true ? item.player.jerseyName!.trim() : item.player.firstName} #${item.player.jerseyNumber}';

                                        return Dismissible(
                                          key: ValueKey(
                                              'uniform-${item.player.id}-${payment?.id ?? 'none'}'),
                                          confirmDismiss: (direction) async {
                                            if (direction ==
                                                DismissDirection.startToEnd) {
                                              await _openPaymentSheet(
                                                context,
                                                season.id,
                                                playerId: item.player.id,
                                                payment: payment,
                                                uniformCampaignId:
                                                    item.campaign.id,
                                              );
                                              return false;
                                            }
                                            if (direction ==
                                                DismissDirection.endToStart) {
                                              await _deletePaymentForCard(
                                                context,
                                                playerLabel,
                                                payment,
                                                'la campana ${item.campaign.name}',
                                              );
                                              return false;
                                            }
                                            return false;
                                          },
                                          background: _SwipeBackground(
                                            alignment: Alignment.centerLeft,
                                            color: Colors.blue.shade600,
                                            icon: Icons.edit_outlined,
                                            label: payment == null
                                                ? 'Registrar'
                                                : 'Editar',
                                          ),
                                          secondaryBackground: _SwipeBackground(
                                            alignment: Alignment.centerRight,
                                            color: Colors.red.shade600,
                                            icon: Icons.delete_outline,
                                            label: 'Eliminar',
                                          ),
                                          child: _UniformPaymentCard(
                                            item: item,
                                            canWritePayments: canWritePayments,
                                            isLoadingReceipt:
                                                payment?.receiptUrl != null &&
                                                    _loadingReceiptPaths
                                                        .contains(
                                                      payment!.receiptUrl!,
                                                    ),
                                            onRegisterOrEdit: canWritePayments
                                                ? () => _openPaymentSheet(
                                                      context,
                                                      season.id,
                                                      playerId: item.player.id,
                                                      payment: payment,
                                                      uniformCampaignId:
                                                          item.campaign.id,
                                                    )
                                                : null,
                                            onViewReceipt:
                                                payment?.receiptUrl == null
                                                    ? null
                                                    : () => _openReceipt(
                                                          context,
                                                          payment!.receiptUrl!,
                                                        ),
                                          ),
                                        );
                                      },
                                    ),
                    ),
                  ],
                );
              },
              loading: () => const Loading(message: 'Cargando temporada...'),
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

class _WeekSelector extends StatelessWidget {
  const _WeekSelector({
    required this.weekStart,
    required this.weekEnd,
    required this.onPrevious,
    required this.onCurrent,
    required this.onNext,
    required this.onPickDate,
  });

  final DateTime weekStart;
  final DateTime weekEnd;
  final VoidCallback onPrevious;
  final VoidCallback onCurrent;
  final VoidCallback onNext;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${AppFormatters.date(weekStart)} - ${AppFormatters.date(weekEnd)}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            OutlinedButton.icon(
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left),
              label: const Text('Semana anterior'),
            ),
            OutlinedButton(
              onPressed: onCurrent,
              child: const Text('Semana actual'),
            ),
            OutlinedButton.icon(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
              label: const Text('Semana siguiente'),
            ),
            TextButton.icon(
              onPressed: onPickDate,
              icon: const Icon(Icons.calendar_today_outlined),
              label: const Text('Elegir fecha'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $value'));
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.textColor,
  });

  final String label;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: BrandColors.gold.withValues(alpha: 0.9),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: textColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: alignment,
      child: Row(
        mainAxisAlignment: alignment == Alignment.centerLeft
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class _TrainingPaymentCard extends StatelessWidget {
  const _TrainingPaymentCard({
    required this.item,
    required this.canWritePayments,
    required this.isLoadingReceipt,
    this.onRegisterOrEdit,
    this.onViewReceipt,
  });

  final WeeklyPlayerPaymentCardData item;
  final bool canWritePayments;
  final bool isLoadingReceipt;
  final VoidCallback? onRegisterOrEdit;
  final VoidCallback? onViewReceipt;

  @override
  Widget build(BuildContext context) {
    final player = item.player;
    final status = item.weekStatus;
    final displayName = (player.jerseyName ?? '').trim().isNotEmpty
        ? player.jerseyName!.trim()
        : player.firstName;
    final state = status.state;
    final chip = switch (state) {
      WeeklyPaymentState.unpaid => ('SIN PAGO', Colors.white70),
      WeeklyPaymentState.partial => ('PAGO PARCIAL', const Color(0xFFF5D77A)),
      WeeklyPaymentState.paid => ('YA PAGÓ', const Color(0xFF8FD6A3)),
    };

    final summary = switch (state) {
      WeeklyPaymentState.unpaid => status.amountExpected > 0
          ? '${AppFormatters.money(status.amountPaid)} / ${AppFormatters.money(status.amountExpected)}'
          : 'Sin pago',
      WeeklyPaymentState.partial =>
        '${AppFormatters.money(status.amountPaid)} / ${AppFormatters.money(status.amountExpected)}',
      WeeklyPaymentState.paid =>
        '${AppFormatters.money(status.amountPaid)} / ${AppFormatters.money(status.amountExpected > 0 ? status.amountExpected : status.amountPaid)}',
    };

    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '$displayName  #${player.jerseyNumber}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Flexible(
              child: Text(
                summary,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _StatusBadge(
                label: chip.$1,
                textColor: chip.$2,
              ),
            ],
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              status.paidAt != null
                  ? 'Pagado: ${AppFormatters.money(status.amountPaid)} • fecha ${AppFormatters.date(status.paidAt!)}'
                  : 'Pagado: ${AppFormatters.money(status.amountPaid)}',
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Adeudos: ${item.debtCount}'),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (canWritePayments)
                OutlinedButton.icon(
                  onPressed: onRegisterOrEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(
                    status.currentPayment == null
                        ? 'Registrar pago'
                        : 'Editar pago',
                  ),
                ),
              if (onViewReceipt != null)
                isLoadingReceipt
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : OutlinedButton.icon(
                        onPressed: onViewReceipt,
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: const Text('Ver recibo'),
                      ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UniformPaymentCard extends StatelessWidget {
  const _UniformPaymentCard({
    required this.item,
    required this.canWritePayments,
    required this.isLoadingReceipt,
    this.onRegisterOrEdit,
    this.onViewReceipt,
  });

  final UniformCampaignPlayerSummary item;
  final bool canWritePayments;
  final bool isLoadingReceipt;
  final VoidCallback? onRegisterOrEdit;
  final VoidCallback? onViewReceipt;

  @override
  Widget build(BuildContext context) {
    final player = item.player;
    final displayName = (player.jerseyName ?? '').trim().isNotEmpty
        ? player.jerseyName!.trim()
        : player.firstName;
    final chip = switch (item.state) {
      UniformCampaignPaymentState.unpaid => ('SIN PAGO', Colors.white70),
      UniformCampaignPaymentState.partial => ('ABONÓ', const Color(0xFFF5D77A)),
      UniformCampaignPaymentState.complete => (
          'PAGÓ COMPLETO',
          const Color(0xFF8FD6A3)
        ),
    };

    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '$displayName  #${player.jerseyNumber}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Flexible(
              child: Text(
                '${AppFormatters.money(item.totalPaid)} / ${AppFormatters.money(item.totalRequired)}',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        subtitle: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _StatusBadge(
              label: chip.$1,
              textColor: chip.$2,
            ),
            Chip(
              visualDensity: VisualDensity.compact,
              label: Text('Falta: ${AppFormatters.money(item.remaining)}'),
            ),
          ],
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Requerido: anticipo ${AppFormatters.money(item.requiredDeposit)} · total ${AppFormatters.money(item.totalRequired)}',
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Abonado: ${AppFormatters.money(item.totalPaid)} · Falta: ${AppFormatters.money(item.remaining)}',
            ),
          ),
          const SizedBox(height: 6),
          if (item.payments.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Sin historial de pagos en esta campana.'),
            )
          else
            ...item.payments.take(3).map(
                  (payment) => Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${AppFormatters.date(payment.paidAt)} • ${AppFormatters.money(payment.paidAmount)}'
                        '${payment.paymentMethod?.trim().isNotEmpty == true ? ' • ${payment.paymentMethod}' : ''}',
                      ),
                    ),
                  ),
                ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (canWritePayments)
                OutlinedButton.icon(
                  onPressed: onRegisterOrEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(
                    item.latestPayment == null
                        ? 'Registrar pago'
                        : 'Editar pago',
                  ),
                ),
              if (onViewReceipt != null)
                isLoadingReceipt
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : OutlinedButton.icon(
                        onPressed: onViewReceipt,
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: const Text('Ver recibo'),
                      ),
            ],
          ),
        ],
      ),
    );
  }
}
