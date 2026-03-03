typedef UUID = String;

bool isWeeklyPaymentConceptName(String? value) {
  final normalized = (value ?? '').trim().toLowerCase();
  return normalized == 'semana' || normalized == 'semanal';
}

bool isUniformPaymentConceptName(String? value) {
  final normalized = (value ?? '').trim().toLowerCase();
  return normalized == 'uniforme';
}

enum PaymentCategory {
  training,
  uniform,
  other,
}

class PaymentDraft {
  const PaymentDraft({
    required this.amount,
    required this.paidAmount,
    required this.status,
  });

  final double amount;
  final double paidAmount;
  final String status;
}

PaymentCategory resolvePaymentCategory({
  String? category,
  String? conceptName,
}) {
  final normalizedCategory = (category ?? '').trim().toLowerCase();
  if (normalizedCategory == 'entrenamiento') return PaymentCategory.training;
  if (normalizedCategory == 'uniforme') return PaymentCategory.uniform;
  if (isWeeklyPaymentConceptName(conceptName)) return PaymentCategory.training;
  if (isUniformPaymentConceptName(conceptName)) return PaymentCategory.uniform;
  return PaymentCategory.other;
}

PaymentDraft normalizePaymentDraft({
  required double amount,
  double? paidAmount,
  String? status,
}) {
  final normalizedAmount = amount < 0 ? 0.0 : amount;
  var normalizedPaidAmount = (paidAmount ?? amount);
  if (normalizedPaidAmount < 0) normalizedPaidAmount = 0;
  if (normalizedPaidAmount > normalizedAmount) {
    normalizedPaidAmount = normalizedAmount;
  }

  var normalizedStatus = (status ?? 'paid').trim().toLowerCase();
  if (normalizedPaidAmount <= 0) {
    normalizedPaidAmount = 0;
    normalizedStatus = 'unpaid';
  } else if (normalizedPaidAmount >= normalizedAmount) {
    normalizedPaidAmount = normalizedAmount;
    normalizedStatus = 'paid';
  } else {
    normalizedStatus = 'partial';
  }

  return PaymentDraft(
    amount: normalizedAmount,
    paidAmount: normalizedPaidAmount,
    status: normalizedStatus,
  );
}

class PaymentRow {
  const PaymentRow({
    required this.id,
    required this.seasonId,
    required this.playerId,
    required this.conceptId,
    required this.amount,
    required this.paidAmount,
    required this.status,
    required this.paidAt,
    this.weekStart,
    this.weekEnd,
    this.notes,
    this.receiptUrl,
    this.createdAt,
    this.createdBy,
    this.paymentMethod,
    this.reference,
    this.uniformCampaignId,
    this.playerName,
    this.conceptName,
    this.conceptCategory,
    this.playerJerseyNumber,
    this.playerJerseyName,
  });

  final UUID id;
  final UUID seasonId;
  final UUID playerId;
  final UUID conceptId;
  final double amount;
  final double paidAmount;
  final String status;
  final DateTime paidAt;
  final DateTime? weekStart;
  final DateTime? weekEnd;
  final String? notes;
  final String? receiptUrl;
  final DateTime? createdAt;
  final UUID? createdBy;
  final String? paymentMethod;
  final String? reference;
  final UUID? uniformCampaignId;
  final String? playerName;
  final String? conceptName;
  final String? conceptCategory;
  final int? playerJerseyNumber;
  final String? playerJerseyName;

  PaymentCategory get paymentCategory => resolvePaymentCategory(
        category: conceptCategory,
        conceptName: conceptName,
      );

  factory PaymentRow.fromMap(Map<String, dynamic> map) {
    final player = map['players'] as Map<String, dynamic>?;
    final concept = map['payment_concepts'] as Map<String, dynamic>?;

    final jerseyName = (player?['jersey_name'] as String?)?.trim();
    final firstName = player?['first_name'] as String?;
    final lastName = player?['last_name'] as String?;
    final jersey = (player?['jersey_number'] as num?)?.toInt();
    final displayName = (jerseyName != null && jerseyName.isNotEmpty)
        ? jerseyName
        : [
            firstName,
            lastName,
          ].whereType<String>().join(' ').trim();
    final playerLabel =
        displayName.isNotEmpty ? '#${jersey ?? '-'} $displayName' : null;

    return PaymentRow(
      id: map['id'] as UUID,
      seasonId: map['season_id'] as UUID,
      playerId: map['player_id'] as UUID,
      conceptId: map['concept_id'] as UUID,
      amount: _parseNumeric(map['amount']),
      paidAmount: _parseNumeric(map['paid_amount'] ?? map['amount']),
      status: (map['status'] as String? ?? 'paid').trim(),
      paidAt: DateTime.parse(map['paid_at'] as String),
      weekStart: map['week_start'] != null
          ? DateTime.parse(map['week_start'] as String)
          : null,
      weekEnd: map['week_end'] != null
          ? DateTime.parse(map['week_end'] as String)
          : null,
      notes: map['notes'] as String?,
      receiptUrl: map['receipt_url'] as String?,
      paymentMethod: map['payment_method'] as String?,
      reference: map['reference'] as String?,
      uniformCampaignId: map['uniform_campaign_id'] as UUID?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      createdBy: map['created_by'] as UUID?,
      playerName: playerLabel,
      conceptName: concept?['name'] as String?,
      conceptCategory: concept?['category'] as String?,
      playerJerseyNumber: jersey,
      playerJerseyName: displayName.isEmpty ? null : displayName,
    );
  }

  static double _parseNumeric(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}

class PaymentConcept {
  const PaymentConcept({
    required this.id,
    required this.name,
    this.amount,
    this.category,
  });

  final String id;
  final String name;
  final double? amount;
  final String? category;

  PaymentCategory get paymentCategory => resolvePaymentCategory(
        category: category,
        conceptName: name,
      );

  factory PaymentConcept.fromMap(Map<String, dynamic> map) {
    return PaymentConcept(
      id: map['id'] as String,
      name: map['name'] as String,
      amount: map['amount'] is num
          ? (map['amount'] as num).toDouble()
          : double.tryParse(map['amount']?.toString() ?? ''),
      category: map['category'] as String?,
    );
  }
}

class PaymentPlayerOption {
  const PaymentPlayerOption({
    required this.id,
    required this.jerseyNumber,
    required this.firstName,
    required this.lastName,
    this.jerseyName,
  });

  final String id;
  final int jerseyNumber;
  final String firstName;
  final String lastName;
  final String? jerseyName;

  String get label {
    final displayName = (jerseyName ?? '').trim();
    if (displayName.isNotEmpty) return '#$jerseyNumber $displayName';
    return '#$jerseyNumber $firstName $lastName';
  }

  factory PaymentPlayerOption.fromMap(Map<String, dynamic> map) {
    return PaymentPlayerOption(
      id: map['id'] as String,
      jerseyNumber: map['jersey_number'] as int,
      firstName: map['first_name'] as String,
      lastName: map['last_name'] as String,
      jerseyName: map['jersey_name'] as String?,
    );
  }
}
