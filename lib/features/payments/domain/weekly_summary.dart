class WeeklySummary {
  const WeeklySummary({
    required this.totalPaid,
    required this.totalPlayers,
    required this.paidPlayers,
    required this.partialPlayers,
    required this.pendingPlayers,
    required this.byPlayer,
  });

  final double totalPaid;
  final int totalPlayers;
  final int paidPlayers;
  final int partialPlayers;
  final int pendingPlayers;
  final List<PlayerWeeklySummary> byPlayer;
}

class PlayerWeeklySummary {
  const PlayerWeeklySummary({
    required this.playerId,
    required this.playerName,
    required this.paymentState,
    required this.requiredAmount,
    required this.paidThisWeek,
    required this.amountPaidThisWeek,
    required this.pending,
  });

  final String playerId;
  final String playerName;
  final String paymentState;
  final double requiredAmount;
  final bool paidThisWeek;
  final double amountPaidThisWeek;
  final bool pending;
}
