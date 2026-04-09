import '../../players/domain/player.dart';
import '../../attendance/domain/attendance_entry.dart';
import 'payment.dart';

final trainingFeeStartDate = DateTime(2026, 3, 30);
const fallbackWeeklyFeeAmount = 130.0;

enum PaymentState {
  pending,
  partial,
  paid,
}

enum WeeklyPaymentState {
  noCharge,
  unpaid,
  partial,
  paid,
}

class WeeklyPaymentStatus {
  const WeeklyPaymentStatus({
    required this.state,
    required this.paymentState,
    required this.amountExpected,
    required this.amountPaid,
    this.currentPayment,
    this.paidAt,
    this.receiptUrl,
    this.presentAttendances = 0,
    this.attendedDates = const <DateTime>[],
  });

  final WeeklyPaymentState state;
  final PaymentState paymentState;
  final double amountExpected;
  final double amountPaid;
  final PaymentRow? currentPayment;
  final DateTime? paidAt;
  final String? receiptUrl;
  final int presentAttendances;
  final List<DateTime> attendedDates;

  double get pendingAmount =>
      (amountExpected - amountPaid).clamp(0, double.infinity);
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
    required this.noChargePlayers,
    required this.paidPlayers,
    required this.partialPlayers,
    required this.pendingPlayers,
    required this.totalDebts,
  });

  final List<WeeklyPlayerPaymentCardData> players;
  final int totalActivePlayers;
  final int noChargePlayers;
  final int paidPlayers;
  final int partialPlayers;
  final int pendingPlayers;
  final int totalDebts;
}

PaymentState resolvePaymentState({
  required double amountPaid,
  required double amountExpected,
}) {
  if (amountPaid <= 0) return PaymentState.pending;
  if (amountExpected > 0 && amountPaid < amountExpected) {
    return PaymentState.partial;
  }
  return PaymentState.paid;
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
    final paymentState = resolvePaymentState(
      amountPaid: totalPaid,
      amountExpected: totalExpected,
    );
    final isPartial = paymentState == PaymentState.partial ||
        (paymentState == PaymentState.paid && hasPartial && totalExpected <= 0);

    return MapEntry(
      playerId,
      WeeklyPaymentStatus(
        state: isPartial ? WeeklyPaymentState.partial : WeeklyPaymentState.paid,
        paymentState: isPartial ? PaymentState.partial : PaymentState.paid,
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

Map<String, WeeklyPaymentStatus> buildTrainingWeeklyStatusMap({
  required List<Player> players,
  required List<PaymentRow> payments,
  required List<AttendanceEntry> attendanceEntries,
  required DateTime weekStart,
}) {
  final grouped = <String, List<PaymentRow>>{};
  for (final payment in payments) {
    if (payment.paymentCategory != PaymentCategory.training) continue;
    final normalizedStatus = payment.status.trim().toLowerCase();
    if ((normalizedStatus != 'paid' && normalizedStatus != 'partial') ||
        payment.paidAmount <= 0) {
      continue;
    }
    grouped.putIfAbsent(payment.playerId, () => <PaymentRow>[]).add(payment);
  }

  final attendanceByPlayer = <String, List<AttendanceEntry>>{};
  for (final entry in attendanceEntries) {
    if (!entry.isPresent) continue;
    attendanceByPlayer
        .putIfAbsent(entry.playerId, () => <AttendanceEntry>[])
        .add(entry);
  }

  final map = <String, WeeklyPaymentStatus>{};

  for (final player in players) {
    final playerId = player.id!;
    final rows = [...(grouped[playerId] ?? const <PaymentRow>[])]
      ..sort((a, b) => b.paidAt.compareTo(a.paidAt));
    final attendances = [...(attendanceByPlayer[playerId] ?? const <AttendanceEntry>[])]
      ..sort((a, b) => a.attendedOn.compareTo(b.attendedOn));
    final presentCount = attendances.length;
    final normalizedExpected = resolveTrainingExpectedAmount(
      paymentMode: player.paymentMode,
      presentAttendances: presentCount,
      weekStart: weekStart,
    );
    final totalPaid = rows.fold<double>(0, (sum, row) => sum + row.paidAmount);
    final paymentState = normalizedExpected <= 0
        ? (totalPaid > 0 ? PaymentState.paid : PaymentState.pending)
        : resolvePaymentState(
            amountPaid: totalPaid,
            amountExpected: normalizedExpected,
          );
    final latest = rows.isEmpty ? null : rows.first;
    final weeklyState = normalizedExpected <= 0
        ? (totalPaid > 0 ? WeeklyPaymentState.paid : WeeklyPaymentState.noCharge)
        : switch (paymentState) {
            PaymentState.pending => WeeklyPaymentState.unpaid,
            PaymentState.partial => WeeklyPaymentState.partial,
            PaymentState.paid => WeeklyPaymentState.paid,
          };

    map[playerId] = WeeklyPaymentStatus(
      state: weeklyState,
      paymentState: paymentState,
      amountExpected: normalizedExpected,
      amountPaid: totalPaid,
      currentPayment: latest,
      paidAt: latest?.paidAt,
      receiptUrl: latest?.receiptUrl,
      presentAttendances: presentCount,
      attendedDates: attendances.map((entry) => entry.attendedOn).toList(),
    );
  }

  return map;
}

List<Player> mergeTrainingBoardPlayers({
  required List<Player> activePlayers,
  required List<PaymentRow> weeklyPayments,
}) {
  final playersById = <String, Player>{
    for (final player in activePlayers)
      if (player.id != null) player.id!: player,
  };

  for (final payment in weeklyPayments) {
    if (payment.paymentCategory != PaymentCategory.training) continue;
    playersById.putIfAbsent(
      payment.playerId,
      () => Player(
        id: payment.playerId,
        seasonId: payment.seasonId,
        jerseyNumber: payment.playerJerseyNumber ?? 0,
        firstName: (payment.playerJerseyName ?? '').trim().isNotEmpty
            ? payment.playerJerseyName!.trim()
            : 'Jugador',
        lastName: '',
        jerseyName: payment.playerJerseyName,
        isActive: false,
        wantsUniform: false,
        paymentMode: 'normal',
      ),
    );
  }

  final players = playersById.values.toList()
    ..sort((a, b) {
      if (a.isActive != b.isActive) {
        return a.isActive ? -1 : 1;
      }
      final jerseyComparison = a.jerseyNumber.compareTo(b.jerseyNumber);
      if (jerseyComparison != 0) return jerseyComparison;
      return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
    });
  return players;
}

double resolveTrainingExpectedAmount({
  required String paymentMode,
  required int presentAttendances,
  required DateTime weekStart,
}) {
  if (getWeekStartMonday(weekStart).isBefore(trainingFeeStartDate)) return 0;
  if (paymentMode.trim().toLowerCase() == 'exempt') return 0;
  return switch (presentAttendances) {
    <= 0 => 0,
    1 => 60,
    2 => 120,
    _ => fallbackWeeklyFeeAmount,
  };
}

Map<String, int> calculatePlayerDebtCounts({
  required List<Player> players,
  required List<PaymentRow> paymentsInRange,
  required List<AttendanceEntry> attendanceEntriesInRange,
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
  final paidByPlayerWeek = <String, double>{};

  for (final payment in paymentsInRange) {
    final normalizedStatus = payment.status.trim().toLowerCase();
    final weekStart = payment.weekStart;
    if ((normalizedStatus != 'paid' && normalizedStatus != 'partial') ||
        payment.paidAmount <= 0 ||
        weekStart == null) {
      continue;
    }
    final weekKey =
        '${payment.playerId}|${getWeekStartMonday(weekStart).toIso8601String()}';
    paidByPlayerWeek[weekKey] = (paidByPlayerWeek[weekKey] ?? 0) + payment.paidAmount;
  }
  final attendanceCountByPlayerWeek = <String, int>{};
  for (final entry in attendanceEntriesInRange) {
    if (!entry.isPresent) continue;
    final weekKey =
        '${entry.playerId}|${getWeekStartMonday(entry.attendedOn).toIso8601String()}';
    attendanceCountByPlayerWeek[weekKey] =
        (attendanceCountByPlayerWeek[weekKey] ?? 0) + 1;
  }

  final debtCounts = <String, int>{};
  for (final player in players) {
    var debtCount = 0;
    for (final week in allWeeks) {
      final weekKey = '${player.id}|${week.toIso8601String()}';
      final expected = resolveTrainingExpectedAmount(
        paymentMode: player.paymentMode,
        presentAttendances: attendanceCountByPlayerWeek[weekKey] ?? 0,
        weekStart: week,
      );
      if (expected <= 0) continue;
      final paid = paidByPlayerWeek[weekKey] ?? 0;
      if (paid < expected) debtCount += 1;
    }
    debtCounts[player.id!] = debtCount;
  }
  return debtCounts;
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
          paymentState: PaymentState.pending,
          amountExpected: 0,
          amountPaid: 0,
        );
    return WeeklyPlayerPaymentCardData(
      player: player,
      weekStatus: status,
      debtCount: debtCountsByPlayer[player.id] ?? 0,
    );
  }).toList();

  final noChargePlayers = cards
      .where((card) => card.weekStatus.state == WeeklyPaymentState.noCharge)
      .length;
  final paidPlayers = cards
      .where((card) => card.weekStatus.state == WeeklyPaymentState.paid)
      .length;
  final partialPlayers = cards
      .where((card) => card.weekStatus.state == WeeklyPaymentState.partial)
      .length;
  final pendingPlayers = cards
      .where((card) => card.weekStatus.state == WeeklyPaymentState.unpaid)
      .length;
  final totalDebts = cards.fold<int>(0, (sum, card) => sum + card.debtCount);

  return WeeklyPaymentsDashboardData(
    players: cards,
    totalActivePlayers: cards.where((card) => card.player.isActive).length,
    noChargePlayers: noChargePlayers,
    paidPlayers: paidPlayers,
    partialPlayers: partialPlayers,
    pendingPlayers: pendingPlayers,
    totalDebts: totalDebts,
  );
}
