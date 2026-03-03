import '../../players/domain/player.dart';
import 'payment.dart';

final trainingFeeStartDate = DateTime(2026, 3, 9);

enum WeeklyPaymentState {
  unpaid,
  partial,
  paid,
}

class WeeklyPaymentStatus {
  const WeeklyPaymentStatus({
    required this.state,
    required this.amountExpected,
    required this.amountPaid,
    this.currentPayment,
    this.paidAt,
    this.receiptUrl,
  });

  final WeeklyPaymentState state;
  final double amountExpected;
  final double amountPaid;
  final PaymentRow? currentPayment;
  final DateTime? paidAt;
  final String? receiptUrl;
}

class WeeklyPlayerPaymentCardData {
  const WeeklyPlayerPaymentCardData({
    required this.player,
    required this.weekStatus,
    required this.debtCount,
  });

  final Player player;
  final WeeklyPaymentStatus weekStatus;
  final int debtCount;
}

class WeeklyPaymentsDashboardData {
  const WeeklyPaymentsDashboardData({
    required this.players,
    required this.totalActivePlayers,
    required this.paidPlayers,
    required this.pendingPlayers,
    required this.totalDebts,
  });

  final List<WeeklyPlayerPaymentCardData> players;
  final int totalActivePlayers;
  final int paidPlayers;
  final int pendingPlayers;
  final int totalDebts;
}

bool playerMatchesSearch(Player player, String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return true;

  final haystack = <String>[
    (player.jerseyName ?? '').trim(),
    player.firstName,
    player.lastName,
    player.jerseyNumber.toString(),
  ].map((value) => value.toLowerCase());

  return haystack.any((value) => value.contains(normalized));
}

DateTime getWeekStartMonday(DateTime date) {
  final local = DateTime(date.year, date.month, date.day);
  return local.subtract(Duration(days: local.weekday - DateTime.monday));
}

DateTime getWeekEndSunday(DateTime weekStart) {
  final monday = getWeekStartMonday(weekStart);
  return monday.add(const Duration(days: 6));
}

List<DateTime> buildSeasonWeekStarts({
  required DateTime seasonStart,
  required DateTime selectedWeekStart,
}) {
  final firstWeek = getWeekStartMonday(seasonStart);
  final lastWeek = getWeekStartMonday(selectedWeekStart);
  if (firstWeek.isAfter(lastWeek)) return const <DateTime>[];

  final weeks = <DateTime>[];
  for (var cursor = firstWeek;
      !cursor.isAfter(lastWeek);
      cursor = cursor.add(const Duration(days: 7))) {
    weeks.add(cursor);
  }
  return weeks;
}

Map<String, WeeklyPaymentStatus> buildWeeklyPaymentStatusMap(
  List<PaymentRow> payments,
) {
  final grouped = <String, List<PaymentRow>>{};
  for (final payment in payments) {
    final normalizedStatus = payment.status.trim().toLowerCase();
    if ((normalizedStatus != 'paid' && normalizedStatus != 'partial') ||
        payment.paidAmount <= 0) {
      continue;
    }
    grouped.putIfAbsent(payment.playerId, () => <PaymentRow>[]).add(payment);
  }

  return grouped.map((playerId, rows) {
    rows.sort((a, b) => b.paidAt.compareTo(a.paidAt));
    final totalExpected =
        rows.fold<double>(0, (sum, payment) => sum + payment.amount);
    final totalPaid =
        rows.fold<double>(0, (sum, payment) => sum + payment.paidAmount);
    final latest = rows.first;
    final hasPartial =
        rows.any((payment) => payment.status.trim().toLowerCase() == 'partial');
    final isPartial = (totalExpected > 0 && totalPaid < totalExpected) ||
        (totalExpected <= 0 && hasPartial);

    return MapEntry(
      playerId,
      WeeklyPaymentStatus(
        state: isPartial ? WeeklyPaymentState.partial : WeeklyPaymentState.paid,
        amountExpected: totalExpected,
        amountPaid: totalPaid,
        currentPayment: latest,
        paidAt: latest.paidAt,
        receiptUrl: rows
                .map((payment) => payment.receiptUrl?.trim())
                .whereType<String>()
                .firstWhere(
                  (value) => value.isNotEmpty,
                  orElse: () => '',
                )
                .trim()
                .isEmpty
            ? null
            : rows
                .map((payment) => payment.receiptUrl?.trim())
                .whereType<String>()
                .firstWhere((value) => value.isNotEmpty),
      ),
    );
  });
}

Map<String, int> calculatePlayerDebtCounts({
  required List<Player> players,
  required List<PaymentRow> paymentsInRange,
  required DateTime seasonStart,
  required DateTime selectedWeekStart,
}) {
  if (selectedWeekStart.isBefore(trainingFeeStartDate)) {
    return {for (final player in players) player.id!: 0};
  }

  final allWeeks = buildSeasonWeekStarts(
    seasonStart: seasonStart.isAfter(trainingFeeStartDate)
        ? seasonStart
        : trainingFeeStartDate,
    selectedWeekStart: selectedWeekStart,
  );
  final paidWeeksByPlayer = <String, Set<String>>{};

  for (final payment in paymentsInRange) {
    final normalizedStatus = payment.status.trim().toLowerCase();
    final weekStart = payment.weekStart;
    if ((normalizedStatus != 'paid' && normalizedStatus != 'partial') ||
        payment.paidAmount <= 0 ||
        weekStart == null) {
      continue;
    }
    paidWeeksByPlayer
        .putIfAbsent(payment.playerId, () => <String>{})
        .add(getWeekStartMonday(weekStart).toIso8601String());
  }

  final totalWeeks = allWeeks.length;
  return {
    for (final player in players)
      player.id!: totalWeeks - (paidWeeksByPlayer[player.id]?.length ?? 0),
  };
}

WeeklyPaymentsDashboardData buildWeeklyPaymentsDashboard({
  required List<Player> players,
  required Map<String, WeeklyPaymentStatus> weeklyStatusByPlayer,
  required Map<String, int> debtCountsByPlayer,
}) {
  final cards = players.map((player) {
    final status = weeklyStatusByPlayer[player.id!] ??
        const WeeklyPaymentStatus(
          state: WeeklyPaymentState.unpaid,
          amountExpected: 0,
          amountPaid: 0,
        );
    return WeeklyPlayerPaymentCardData(
      player: player,
      weekStatus: status,
      debtCount: debtCountsByPlayer[player.id] ?? 0,
    );
  }).toList();

  final paidPlayers = cards
      .where((card) => card.weekStatus.state == WeeklyPaymentState.paid)
      .length;
  final pendingPlayers = cards.length - paidPlayers;
  final totalDebts = cards.fold<int>(0, (sum, card) => sum + card.debtCount);

  return WeeklyPaymentsDashboardData(
    players: cards,
    totalActivePlayers: cards.length,
    paidPlayers: paidPlayers,
    pendingPlayers: pendingPlayers,
    totalDebts: totalDebts,
  );
}
