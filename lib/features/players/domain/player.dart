class Player {
  const Player({
    this.id,
    required this.seasonId,
    required this.jerseyNumber,
    required this.firstName,
    required this.lastName,
    this.jerseyName,
    this.position,
    this.jerseySize,
    this.uniformGender,
    this.phone,
    this.emergencyContact,
    String? photoPath,
    String? photoThumbPath,
    String? photoUrl,
    String? photoThumbUrl,
    this.age,
    this.heightCm,
    this.weightKg,
    this.notes,
    this.isActive = true,
    this.wantsUniform = true,
    this.createdAt,
  })  : photoPath = photoPath ?? photoUrl,
        photoThumbPath = photoThumbPath ?? photoThumbUrl;

  final String? id;
  final String seasonId;
  final int jerseyNumber;
  final String firstName;
  final String lastName;
  final String? jerseyName;
  final String? position;
  final String? jerseySize;
  final String? uniformGender;
  final String? phone;
  final String? emergencyContact;
  final String? photoPath;
  final String? photoThumbPath;
  final int? age;
  final int? heightCm;
  final double? weightKg;
  final String? notes;
  final bool isActive;
  final bool wantsUniform;
  final DateTime? createdAt;

  @Deprecated('Usa photoPath')
  String? get photoUrl => photoPath;

  @Deprecated('Usa photoThumbPath')
  String? get photoThumbUrl => photoThumbPath;

  String get fullName => '$firstName $lastName'.trim();
  String get initials {
    final first = firstName.trim().isNotEmpty ? firstName.trim()[0] : '';
    final last = lastName.trim().isNotEmpty ? lastName.trim()[0] : '';
    final value = '$first$last'.toUpperCase();
    return value.isEmpty ? '?' : value;
  }

  Player copyWith({
    String? id,
    String? seasonId,
    int? jerseyNumber,
    String? firstName,
    String? lastName,
    String? jerseyName,
    String? position,
    String? jerseySize,
    String? uniformGender,
    String? phone,
    String? emergencyContact,
    String? photoPath,
    String? photoThumbPath,
    String? photoUrl,
    String? photoThumbUrl,
    int? age,
    int? heightCm,
    double? weightKg,
    String? notes,
    bool? isActive,
    bool? wantsUniform,
    DateTime? createdAt,
  }) {
    return Player(
      id: id ?? this.id,
      seasonId: seasonId ?? this.seasonId,
      jerseyNumber: jerseyNumber ?? this.jerseyNumber,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      jerseyName: jerseyName ?? this.jerseyName,
      position: position ?? this.position,
      jerseySize: jerseySize ?? this.jerseySize,
      uniformGender: uniformGender ?? this.uniformGender,
      phone: phone ?? this.phone,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      photoPath: photoPath ?? photoUrl ?? this.photoPath,
      photoThumbPath: photoThumbPath ?? photoThumbUrl ?? this.photoThumbPath,
      age: age ?? this.age,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      wantsUniform: wantsUniform ?? this.wantsUniform,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    final normalizedPhotoPath = photoPath?.trim();
    final normalizedPhotoThumbPath = photoThumbPath?.trim();
    final map = <String, dynamic>{
      'season_id': seasonId,
      'jersey_number': jerseyNumber,
      'first_name': firstName,
      'last_name': lastName,
      'jersey_name':
          (jerseyName ?? '').trim().isEmpty ? null : jerseyName!.trim(),
      'position': position,
      'jersey_size': jerseySize,
      'uniform_gender': uniformGender,
      'phone': phone,
      'emergency_contact': emergencyContact,
      'age': age,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'notes': notes,
      'is_active': isActive,
      'wants_uniform': wantsUniform,
    };

    if (normalizedPhotoPath != null && normalizedPhotoPath.isNotEmpty) {
      map['photo_path'] = normalizedPhotoPath;
    }
    if (normalizedPhotoThumbPath != null &&
        normalizedPhotoThumbPath.isNotEmpty) {
      map['photo_thumb_path'] = normalizedPhotoThumbPath;
    }

    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory Player.fromMap(Map<String, dynamic> map) {
    final parsedPhotoPath =
        (map['photo_path'] as String?) ?? _legacyToPath(map['photo_url']);
    final parsedPhotoThumbPath = (map['photo_thumb_path'] as String?) ??
        _legacyToPath(map['photo_thumb_url']);

    return Player(
      id: map['id'] as String,
      seasonId: map['season_id'] as String,
      jerseyNumber: map['jersey_number'] as int,
      firstName: map['first_name'] as String,
      lastName: map['last_name'] as String,
      jerseyName: map['jersey_name'] as String?,
      position: map['position'] as String?,
      jerseySize: map['jersey_size'] as String?,
      uniformGender: (map['uniform_gender'] ?? map['gender']) as String?,
      phone: map['phone'] as String?,
      emergencyContact: map['emergency_contact'] as String?,
      photoPath: parsedPhotoPath,
      photoThumbPath: parsedPhotoThumbPath,
      age: map['age'] as int?,
      heightCm: map['height_cm'] as int?,
      weightKg: (map['weight_kg'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
      isActive: (map['is_active'] as bool?) ?? true,
      wantsUniform: (map['wants_uniform'] as bool?) ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }

  static String? _legacyToPath(dynamic raw) {
    final value = raw is String ? raw.trim() : '';
    if (value.isEmpty) return null;
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      return value.split('?').first;
    }

    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    final segments = uri.pathSegments;
    final bucketIndex = segments.indexOf('player_photos');
    if (bucketIndex == -1 || bucketIndex + 1 >= segments.length) return null;
    return segments.sublist(bucketIndex + 1).join('/');
  }
}
