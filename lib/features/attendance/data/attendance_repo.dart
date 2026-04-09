import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/attendance_entry.dart';

class AttendanceRepo {
  AttendanceRepo(this._client);

  final SupabaseClient _client;
  static const _trainingSessionType = 'training';
  static const _trainingSessionSelect = 'id, season_id, session_date';
  static const _attendanceSelect =
      'id, session_id, player_id, status, visit_fee, notes, created_at';

  Future<bool> hasTrainingSessionOnDate(
    String seasonId,
    DateTime date,
  ) async {
    final data = await _client
        .from('training_sessions')
        .select('id')
        .eq('season_id', seasonId)
        .eq('session_date', _asDate(date))
        .eq('session_type', _trainingSessionType)
        .maybeSingle();
    return data != null;
  }

  Future<String> ensureTrainingSession(
    String seasonId,
    DateTime date, {
    String? notes,
  }) async {
    final saved = await _client
        .from('training_sessions')
        .upsert({
          'season_id': seasonId,
          'session_date': _asDate(date),
          'session_type': _trainingSessionType,
          'notes': (notes ?? '').trim().isEmpty ? null : notes!.trim(),
        }, onConflict: 'season_id,session_date,session_type')
        .select('id')
        .single();

    return saved['id'] as String;
  }

  Future<List<AttendanceEntry>> listAttendanceBySeasonAndDate(
    String seasonId,
    DateTime date,
  ) async {
    final session = await _findTrainingSessionByDate(seasonId, date);
    if (session == null) return const <AttendanceEntry>[];

    final data = await _client
        .from('player_attendances')
        .select(_attendanceSelect)
        .eq('session_id', session.id)
        .order('created_at', ascending: true);

    return (data as List<dynamic>).cast<Map<String, dynamic>>().map((row) {
      return _mapAttendanceRow(
        row,
        seasonId: session.seasonId,
        sessionDate: session.sessionDate,
      );
    }).toList();
  }

  Future<AttendanceEntry> upsertAttendance({
    required String sessionId,
    required String playerId,
    required AttendanceStatus status,
    double? visitFee,
    String? notes,
  }) async {
    final session = await _getTrainingSessionById(sessionId);
    if (session == null) {
      throw StateError('Training session not found for id $sessionId.');
    }

    final saved = await _client
        .from('player_attendances')
        .upsert({
          'session_id': sessionId,
          'player_id': playerId,
          'status': attendanceStatusToString(status),
          'visit_fee': visitFee,
          'notes': (notes ?? '').trim().isEmpty ? null : notes!.trim(),
        }, onConflict: 'session_id,player_id')
        .select(_attendanceSelect)
        .single();

    return _mapAttendanceRow(
      saved,
      seasonId: session.seasonId,
      sessionDate: session.sessionDate,
    );
  }

  Future<List<DateTime>> listAttendanceDatesByPlayer(
    String playerId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final attendanceRows = await _client
        .from('player_attendances')
        .select('session_id')
        .eq('player_id', playerId)
        .eq('status', 'present');

    final sessionIds = (attendanceRows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((row) => row['session_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    if (sessionIds.isEmpty) return const <DateTime>[];

    final sessions = await _client
        .from('training_sessions')
        .select('id, session_date')
        .inFilter('id', sessionIds)
        .eq('session_type', _trainingSessionType)
        .gte('session_date', _asDate(from))
        .lte('session_date', _asDate(to))
        .order('session_date', ascending: true);

    return (sessions as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((row) => DateTime.parse(row['session_date'] as String))
        .toList();
  }

  Future<List<AttendanceEntry>> listAttendanceForWeek({
    required String seasonId,
    required DateTime weekStart,
    required DateTime weekEnd,
  }) async {
    return listAttendanceForRange(
      seasonId: seasonId,
      from: weekStart,
      to: weekEnd,
    );
  }

  Future<List<AttendanceEntry>> listAttendanceForRange({
    required String seasonId,
    required DateTime from,
    required DateTime to,
  }) async {
    final sessionsById = await _listTrainingSessionsInRange(
      seasonId: seasonId,
      from: from,
      to: to,
    );
    if (sessionsById.isEmpty) return const <AttendanceEntry>[];

    final data = await _client
        .from('player_attendances')
        .select(_attendanceSelect)
        .inFilter('session_id', sessionsById.keys.toList())
        .order('created_at', ascending: true);

    final entries =
        (data as List<dynamic>).cast<Map<String, dynamic>>().map((row) {
      final sessionId = row['session_id'] as String?;
      final session = sessionId == null ? null : sessionsById[sessionId];
      if (session == null) {
        throw StateError('Training session metadata not found for id $sessionId.');
      }
      return _mapAttendanceRow(
        row,
        seasonId: session.seasonId,
        sessionDate: session.sessionDate,
      );
    }).toList()
          ..sort((a, b) {
            final dateCompare = a.attendedOn.compareTo(b.attendedOn);
            if (dateCompare != 0) return dateCompare;
            final createdA = a.createdAt ?? DateTime(1970);
            final createdB = b.createdAt ?? DateTime(1970);
            return createdA.compareTo(createdB);
          });

    return entries;
  }

  static String _asDate(DateTime date) =>
      DateTime(date.year, date.month, date.day)
          .toIso8601String()
          .split('T')
          .first;

  Future<({String id, String seasonId, DateTime sessionDate})?>
      _findTrainingSessionByDate(
    String seasonId,
    DateTime date,
  ) async {
    final data = await _client
        .from('training_sessions')
        .select(_trainingSessionSelect)
        .eq('season_id', seasonId)
        .eq('session_date', _asDate(date))
        .eq('session_type', _trainingSessionType)
        .maybeSingle();
    if (data == null) return null;
    return (
      id: data['id'] as String,
      seasonId: data['season_id'] as String,
      sessionDate: DateTime.parse(data['session_date'] as String),
    );
  }

  Future<({String seasonId, DateTime sessionDate})?> _getTrainingSessionById(
    String sessionId,
  ) async {
    final data = await _client
        .from('training_sessions')
        .select(_trainingSessionSelect)
        .eq('id', sessionId)
        .eq('session_type', _trainingSessionType)
        .maybeSingle();
    if (data == null) return null;
    return (
      seasonId: data['season_id'] as String,
      sessionDate: DateTime.parse(data['session_date'] as String),
    );
  }

  Future<Map<String, ({String seasonId, DateTime sessionDate})>>
      _listTrainingSessionsInRange({
    required String seasonId,
    required DateTime from,
    required DateTime to,
  }) async {
    final data = await _client
        .from('training_sessions')
        .select(_trainingSessionSelect)
        .eq('season_id', seasonId)
        .eq('session_type', _trainingSessionType)
        .gte('session_date', _asDate(from))
        .lte('session_date', _asDate(to))
        .order('session_date', ascending: true);

    final rows = (data as List<dynamic>).cast<Map<String, dynamic>>();
    return {
      for (final row in rows)
        row['id'] as String: (
          seasonId: row['season_id'] as String,
          sessionDate: DateTime.parse(row['session_date'] as String),
        ),
    };
  }

  AttendanceEntry _mapAttendanceRow(
    Map<String, dynamic> row, {
    required String seasonId,
    required DateTime sessionDate,
  }) {
    return AttendanceEntry(
      id: row['id'] as String?,
      sessionId: row['session_id'] as String?,
      seasonId: seasonId,
      playerId: row['player_id'] as String,
      attendedOn: DateTime(sessionDate.year, sessionDate.month, sessionDate.day),
      status: attendanceStatusFromString(row['status'] as String? ?? 'absent'),
      visitFee: _parseNumeric(row['visit_fee']),
      notes: row['notes'] as String?,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : null,
    );
  }

  double? _parseNumeric(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
