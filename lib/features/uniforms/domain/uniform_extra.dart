class UniformExtra {
  const UniformExtra({
    this.id,
    required this.seasonId,
    required this.name,
    this.quantity = 1,
    this.jerseyNumber,
    this.jerseySize,
    this.uniformGender,
    this.notes,
    this.createdAt,
  });

  final String? id;
  final String seasonId;
  final String name;
  final int quantity;
  final int? jerseyNumber;
  final String? jerseySize;
  final String? uniformGender;
  final String? notes;
  final DateTime? createdAt;

  UniformExtra copyWith({
    String? id,
    String? seasonId,
    String? name,
    int? quantity,
    int? jerseyNumber,
    String? jerseySize,
    String? uniformGender,
    String? notes,
    DateTime? createdAt,
  }) {
    return UniformExtra(
      id: id ?? this.id,
      seasonId: seasonId ?? this.seasonId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      jerseyNumber: jerseyNumber ?? this.jerseyNumber,
      jerseySize: jerseySize ?? this.jerseySize,
      uniformGender: uniformGender ?? this.uniformGender,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'season_id': seasonId,
      'name': name,
      'quantity': quantity,
      'jersey_number': jerseyNumber,
      'jersey_size': jerseySize,
      'uniform_gender': uniformGender,
      'notes': notes,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory UniformExtra.fromMap(Map<String, dynamic> map) {
    return UniformExtra(
      id: map['id'] as String?,
      seasonId: map['season_id'] as String,
      name: map['name'] as String,
      quantity: ((map['quantity'] ?? map['qty']) as num?)?.toInt() ?? 1,
      jerseyNumber: (map['jersey_number'] as num?)?.toInt(),
      jerseySize: map['jersey_size'] as String?,
      uniformGender: (map['uniform_gender'] ?? map['gender']) as String?,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }
}
