typedef UUID = String;

enum AttendanceStatus {
  present,
  absent,
}

AttendanceStatus attendanceStatusFromString(String value) {
  return switch (value.trim().toLowerCase()) {
    'present' => AttendanceStatus.present,
    'absent' => AttendanceStatus.absent,
    _ => AttendanceStatus.absent,
  };
}

String attendanceStatusToString(AttendanceStatus value) {
  return switch (value) {
    AttendanceStatus.present => 'present',
    AttendanceStatus.absent => 'absent',
  };
}

class AttendanceEntry {
  const AttendanceEntry({
    this.id,
    this.sessionId,
    required this.seasonId,
    required this.playerId,
    required this.attendedOn,
    required this.status,
    this.visitFee,
    this.notes,
    this.createdAt,
  });

  final UUID? id;
  final UUID? sessionId;
  final UUID seasonId;
  final UUID playerId;
  final DateTime attendedOn;
  final AttendanceStatus status;
  final double? visitFee;
  final String? notes;
  final DateTime? createdAt;

  bool get isPresent => status == AttendanceStatus.present;

  AttendanceEntry copyWith({
    UUID? id,
    UUID? sessionId,
    UUID? seasonId,
    UUID? playerId,
    DateTime? attendedOn,
    AttendanceStatus? status,
    double? visitFee,
    String? notes,
    DateTime? createdAt,
  }) {
    return AttendanceEntry(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      seasonId: seasonId ?? this.seasonId,
      playerId: playerId ?? this.playerId,
      attendedOn: attendedOn ?? this.attendedOn,
      status: status ?? this.status,
      visitFee: visitFee ?? this.visitFee,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      if (sessionId != null) 'session_id': sessionId,
      'player_id': playerId,
      'status': attendanceStatusToString(status),
      'visit_fee': visitFee,
      'notes': (notes ?? '').trim().isEmpty ? null : notes!.trim(),
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory AttendanceEntry.fromMap(Map<String, dynamic> map) {
    final trainingSession = map['training_sessions'] as Map<String, dynamic>?;
    final rawSeasonId =
        trainingSession?['season_id'] as UUID? ?? map['season_id'] as UUID?;
    final rawSessionDate =
        trainingSession?['session_date'] ?? map['attended_on'];

    return AttendanceEntry(
      id: map['id'] as UUID?,
      sessionId: map['session_id'] as UUID?,
      seasonId: rawSeasonId ?? '',
      playerId: map['player_id'] as UUID,
      attendedOn: _parseDate(rawSessionDate),
      status: attendanceStatusFromString(map['status'] as String? ?? 'absent'),
      visitFee: _parseNumeric(map['visit_fee']),
      notes: map['notes'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value is DateTime) {
      return DateTime(value.year, value.month, value.day);
    }
    if (value is String && value.trim().isNotEmpty) {
      final parsed = DateTime.parse(value);
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
    return DateTime(1970, 1, 1);
  }

  static double? _parseNumeric(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
