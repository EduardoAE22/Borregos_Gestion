class PlayerMetric {
  const PlayerMetric({
    this.id,
    required this.playerId,
    required this.measuredOn,
    this.fortyYdSeconds,
    this.tenYdSplit,
    this.shuttle5105,
    this.verticalJumpCm,
    this.notes,
    this.createdAt,
  });

  final String? id;
  final String playerId;
  final DateTime measuredOn;
  final double? fortyYdSeconds;
  final double? tenYdSplit;
  final double? shuttle5105;
  final double? verticalJumpCm;
  final String? notes;
  final DateTime? createdAt;

  PlayerMetric copyWith({
    String? id,
    String? playerId,
    DateTime? measuredOn,
    double? fortyYdSeconds,
    double? tenYdSplit,
    double? shuttle5105,
    double? verticalJumpCm,
    String? notes,
    DateTime? createdAt,
  }) {
    return PlayerMetric(
      id: id ?? this.id,
      playerId: playerId ?? this.playerId,
      measuredOn: measuredOn ?? this.measuredOn,
      fortyYdSeconds: fortyYdSeconds ?? this.fortyYdSeconds,
      tenYdSplit: tenYdSplit ?? this.tenYdSplit,
      shuttle5105: shuttle5105 ?? this.shuttle5105,
      verticalJumpCm: verticalJumpCm ?? this.verticalJumpCm,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'player_id': playerId,
      'measured_on': measuredOn.toIso8601String().split('T').first,
      'forty_yd_seconds': fortyYdSeconds,
      'ten_yd_split': tenYdSplit,
      'shuttle_5_10_5': shuttle5105,
      'vertical_jump_cm': verticalJumpCm,
      'notes': notes,
    };

    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory PlayerMetric.fromMap(Map<String, dynamic> map) {
    return PlayerMetric(
      id: map['id'] as String,
      playerId: map['player_id'] as String,
      measuredOn: DateTime.parse(map['measured_on'] as String),
      fortyYdSeconds: (map['forty_yd_seconds'] as num?)?.toDouble(),
      tenYdSplit: (map['ten_yd_split'] as num?)?.toDouble(),
      shuttle5105: (map['shuttle_5_10_5'] as num?)?.toDouble(),
      verticalJumpCm: (map['vertical_jump_cm'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }
}
