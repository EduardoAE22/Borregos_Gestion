import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../players/domain/player.dart';
import '../../players/providers/players_providers.dart';
import '../../seasons/providers/seasons_providers.dart';
import '../data/payments_repo.dart';
import '../domain/payment.dart';
import '../domain/uniform_campaign.dart';
import '../domain/weekly_payments_board.dart';
import '../domain/weekly_summary.dart';

class PaymentsQuery {
  const PaymentsQuery({
    required this.seasonId,
    this.from,
    this.to,
  });

  final String seasonId;
  final DateTime? from;
  final DateTime? to;

  @override
  bool operator ==(Object other) {
    return other is PaymentsQuery &&
        seasonId == other.seasonId &&
        from == other.from &&
        to == other.to;
  }

  @override
  int get hashCode => Object.hash(seasonId, from, to);
}

final paymentsRepoProvider = Provider<PaymentsRepo>((ref) {
  return PaymentsRepo(Supabase.instance.client);
});

final paymentsListProvider =
    FutureProvider.family<List<PaymentRow>, PaymentsQuery>((ref, query) async {
  return ref.read(paymentsRepoProvider).listPaymentsBySeason(
        query.seasonId,
        from: query.from,
        to: query.to,
      );
});

final paymentsByActiveSeasonProvider =
    FutureProvider<List<PaymentRow>>((ref) async {
  final seasonId = ref.watch(activeSeasonIdProvider);
  if (seasonId == null) return [];
  return ref.read(paymentsRepoProvider).listPaymentsBySeason(seasonId);
});

final paymentConceptsProvider =
    FutureProvider<List<PaymentConcept>>((ref) async {
  return ref.read(paymentsRepoProvider).listConceptsActive();
});

final weeklyPaymentConceptProvider = FutureProvider<String?>((ref) async {
  return ref.read(paymentsRepoProvider).getPaymentConceptWeekly();
});

final uniformPaymentConceptProvider = FutureProvider<String?>((ref) async {
  return ref.read(paymentsRepoProvider).getPaymentConceptUniform();
});

final seasonPlayersForPaymentProvider =
    FutureProvider.family<List<PaymentPlayerOption>, String>(
        (ref, seasonId) async {
  return ref.read(paymentsRepoProvider).listSeasonPlayers(seasonId);
});

final weeklySummaryProvider = FutureProvider.family<WeeklySummary,
    ({String seasonId, DateTime weekStart})>((ref, args) {
  return ref
      .read(paymentsRepoProvider)
      .weeklySummary(args.seasonId, args.weekStart);
});

final activeSeasonActivePlayersProvider =
    FutureProvider<List<Player>>((ref) async {
  final players = await ref.watch(playersByActiveSeasonProvider.future);
  final activePlayers = players.where((player) => player.isActive).toList()
    ..sort((a, b) => a.jerseyNumber.compareTo(b.jerseyNumber));
  return activePlayers;
});

final weeklyPaymentsBySeasonProvider =
    FutureProvider.family<List<PaymentRow>, DateTime>((ref, weekStart) async {
  final season = await ref.watch(activeSeasonProvider.future);
  if (season == null) return const <PaymentRow>[];
  return ref.read(paymentsRepoProvider).listPaymentsForWeek(
        seasonId: season.id,
        weekStart: getWeekStartMonday(weekStart),
      );
});

final weeklyPaymentsByCategoryProvider = FutureProvider.family<List<PaymentRow>,
    ({DateTime weekStart, PaymentCategory category})>((ref, args) async {
  final season = await ref.watch(activeSeasonProvider.future);
  if (season == null) return const <PaymentRow>[];
  return ref.read(paymentsRepoProvider).listPaymentsForWeekByCategory(
        seasonId: season.id,
        weekStart: getWeekStartMonday(args.weekStart),
        weekEnd: getWeekEndSunday(args.weekStart),
        category: args.category,
      );
});

final paymentsRangeBySeasonProvider = FutureProvider.family<List<PaymentRow>,
    ({DateTime fromWeekStart, DateTime toWeekStart})>((ref, args) async {
  final season = await ref.watch(activeSeasonProvider.future);
  if (season == null) return const <PaymentRow>[];
  return ref.read(paymentsRepoProvider).listPaymentsForRange(
        seasonId: season.id,
        fromWeekStart: getWeekStartMonday(args.fromWeekStart),
        toWeekStart: getWeekStartMonday(args.toWeekStart),
      );
});

final paymentsByCategoryProvider =
    FutureProvider.family<List<PaymentRow>, PaymentCategory>(
        (ref, category) async {
  final season = await ref.watch(activeSeasonProvider.future);
  if (season == null) return const <PaymentRow>[];
  return ref.read(paymentsRepoProvider).listPaymentsByCategory(
        seasonId: season.id,
        category: category,
      );
});

final uniformPaymentsForCampaignProvider =
    FutureProvider.family<List<PaymentRow>, String>((ref, campaignId) async {
  final season = await ref.watch(activeSeasonProvider.future);
  if (season == null) return const <PaymentRow>[];
  final players = await ref.watch(activeSeasonActivePlayersProvider.future);
  final playerIds =
      players.map((player) => player.id).whereType<String>().toList();
  return ref.read(paymentsRepoProvider).listUniformPaymentsForCampaign(
        seasonId: season.id,
        campaignId: campaignId,
        playerIds: playerIds,
      );
});

final uniformCampaignPlayerSummariesProvider =
    FutureProvider.family<List<UniformCampaignPlayerSummary>, UniformCampaign>(
        (ref, campaign) async {
  final players = await ref.watch(activeSeasonActivePlayersProvider.future);
  final payments =
      await ref.watch(uniformPaymentsForCampaignProvider(campaign.id).future);

  return buildUniformCampaignPlayerSummaries(
    players: players,
    campaign: campaign,
    payments: payments,
  );
});

final paymentStatusMapByCategoryProvider = FutureProvider.family<
    Map<String, WeeklyPaymentStatus>,
    ({DateTime weekStart, PaymentCategory category})>((ref, args) async {
  final payments = await ref.watch(
    weeklyPaymentsByCategoryProvider(
      (
        weekStart: args.weekStart,
        category: args.category,
      ),
    ).future,
  );
  return buildWeeklyPaymentStatusMap(payments);
});

final debtByPlayerByCategoryProvider = FutureProvider.family<
    Map<String, int>,
    ({
      DateTime selectedWeekStart,
      PaymentCategory category
    })>((ref, args) async {
  final season = await ref.watch(activeSeasonProvider.future);
  if (season == null) return const <String, int>{};
  final players = await ref.watch(activeSeasonActivePlayersProvider.future);

  if (args.category == PaymentCategory.uniform) {
    return {for (final player in players) player.id!: 0};
  }

  final normalizedWeekStart = getWeekStartMonday(args.selectedWeekStart);
  final fromWeekStart = getWeekStartMonday(season.startsOn);
  final payments = await ref.watch(
    paymentsRangeBySeasonProvider(
      (
        fromWeekStart: fromWeekStart,
        toWeekStart: normalizedWeekStart,
      ),
    ).future,
  );

  return calculatePlayerDebtCounts(
    players: players,
    paymentsInRange: payments
        .where((payment) => payment.paymentCategory == args.category)
        .toList(),
    seasonStart: season.startsOn,
    selectedWeekStart: normalizedWeekStart,
  );
});

final weeklyPaymentStatusByPlayerProvider =
    FutureProvider.family<Map<String, WeeklyPaymentStatus>, DateTime>(
        (ref, weekStart) async {
  return ref.watch(
    paymentStatusMapByCategoryProvider(
      (
        weekStart: weekStart,
        category: PaymentCategory.training,
      ),
    ).future,
  );
});

final weeklyDebtCountsByPlayerProvider =
    FutureProvider.family<Map<String, int>, DateTime>((ref, weekStart) async {
  return ref.watch(
    debtByPlayerByCategoryProvider(
      (
        selectedWeekStart: weekStart,
        category: PaymentCategory.training,
      ),
    ).future,
  );
});

final weeklyPaymentsDashboardProvider =
    FutureProvider.family<WeeklyPaymentsDashboardData, DateTime>(
        (ref, weekStart) async {
  final players = await ref.watch(activeSeasonActivePlayersProvider.future);
  final statusByPlayer =
      await ref.watch(weeklyPaymentStatusByPlayerProvider(weekStart).future);
  final debtCounts =
      await ref.watch(weeklyDebtCountsByPlayerProvider(weekStart).future);

  return buildWeeklyPaymentsDashboard(
    players: players,
    weeklyStatusByPlayer: statusByPlayer,
    debtCountsByPlayer: debtCounts,
  );
});
