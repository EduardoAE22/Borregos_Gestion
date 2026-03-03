import '../../players/domain/player.dart';
import 'payment.dart';

typedef UUID = String;

class UniformCampaign {
  const UniformCampaign({
    required this.id,
    required this.seasonId,
    required this.name,
    this.provider,
    required this.unitPrice,
    required this.depositPercent,
    this.notes,
    this.isActive = true,
    this.createdAt,
  });

  final UUID id;
  final UUID seasonId;
  final String name;
  final String? provider;
  final double unitPrice;
  final double depositPercent;
  final String? notes;
  final bool isActive;
  final DateTime? createdAt;

  double get depositAmount => calculateUniformCampaignDeposit(
        unitPrice: unitPrice,
        depositPercent: depositPercent,
      );

  factory UniformCampaign.fromMap(Map<String, dynamic> map) {
    return UniformCampaign(
      id: map['id'] as UUID,
      seasonId: map['season_id'] as UUID,
      name: (map['name'] as String? ?? '').trim(),
      provider: (map['provider'] as String?)?.trim(),
      unitPrice: _parseNumeric(map['unit_price']),
      depositPercent: _parseNumeric(map['deposit_percent']),
      notes: (map['notes'] as String?)?.trim(),
      isActive: map['is_active'] as bool? ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'season_id': seasonId,
      'name': name.trim(),
      'provider': (provider ?? '').trim().isEmpty ? null : provider!.trim(),
      'unit_price': unitPrice,
      'deposit_percent': depositPercent,
      'notes': (notes ?? '').trim().isEmpty ? null : notes!.trim(),
      'is_active': isActive,
    };
  }

  static double _parseNumeric(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}

double calculateUniformCampaignDeposit({
  required double unitPrice,
  required double depositPercent,
}) {
  if (unitPrice <= 0 || depositPercent <= 0) return 0;
  return unitPrice * (depositPercent / 100);
}

enum UniformCampaignPaymentState {
  unpaid,
  partial,
  complete,
}

class UniformCampaignPlayerSummary {
  const UniformCampaignPlayerSummary({
    required this.player,
    required this.campaign,
    required this.payments,
    required this.totalPaid,
  });

  final Player player;
  final UniformCampaign campaign;
  final List<PaymentRow> payments;
  final double totalPaid;

  double get requiredDeposit => campaign.depositAmount;
  double get totalRequired => campaign.unitPrice;
  double get remaining =>
      (campaign.unitPrice - totalPaid).clamp(0, double.infinity);
  PaymentRow? get latestPayment => payments.isEmpty ? null : payments.first;

  UniformCampaignPaymentState get state {
    if (totalPaid >= campaign.unitPrice && campaign.unitPrice > 0) {
      return UniformCampaignPaymentState.complete;
    }
    if (totalPaid > 0) return UniformCampaignPaymentState.partial;
    return UniformCampaignPaymentState.unpaid;
  }
}

List<UniformCampaignPlayerSummary> buildUniformCampaignPlayerSummaries({
  required List<Player> players,
  required UniformCampaign campaign,
  required List<PaymentRow> payments,
}) {
  final grouped = <String, List<PaymentRow>>{};
  for (final payment in payments) {
    if (payment.uniformCampaignId != campaign.id) continue;
    grouped.putIfAbsent(payment.playerId, () => <PaymentRow>[]).add(payment);
  }

  return players.map((player) {
    final playerPayments = [...(grouped[player.id] ?? const <PaymentRow>[])]
      ..sort((a, b) => b.paidAt.compareTo(a.paidAt));
    final totalPaid = playerPayments.fold<double>(
      0,
      (sum, payment) => sum + payment.paidAmount,
    );
    return UniformCampaignPlayerSummary(
      player: player,
      campaign: campaign,
      payments: playerPayments,
      totalPaid: totalPaid,
    );
  }).toList();
}
