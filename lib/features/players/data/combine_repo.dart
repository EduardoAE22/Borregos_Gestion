import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/combine.dart';

class CombineRepo {
  CombineRepo(this._client);

  final SupabaseClient _client;

  Future<List<CombineSession>> listSessions(String seasonId) async {
    final data = await _client
        .from('combine_sessions')
        .select('id, season_id, nombre, fecha, notas, created_at')
        .eq('season_id', seasonId)
        .order('fecha', ascending: false)
        .order('created_at', ascending: false);

    return (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(CombineSession.fromMap)
        .toList();
  }

  Future<CombineSession> createSession({
    required String seasonId,
    required String nombre,
    required DateTime fecha,
    String? notas,
  }) async {
    final data = await _client
        .from('combine_sessions')
        .insert(
          CombineSession(
            id: '',
            seasonId: seasonId,
            nombre: nombre,
            fecha: fecha,
            notas: notas,
          ).toMap(),
        )
        .select('id, season_id, nombre, fecha, notas, created_at')
        .single();

    return CombineSession.fromMap(data);
  }

  Future<List<CombineTest>> listTests() async {
    final data = await _client
        .from('combine_tests')
        .select('id, codigo, nombre, unidad, mejor, es_activa')
        .eq('es_activa', true)
        .order('nombre', ascending: true);

    return (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(CombineTest.fromMap)
        .toList();
  }

  Future<Map<String, CombineResult>> getPlayerResults({
    required String sessionId,
    required String playerId,
  }) async {
    final data = await _client
        .from('combine_results')
        .select(
            'id, session_id, player_id, test_id, valor, extras, intento, created_at')
        .eq('session_id', sessionId)
        .eq('player_id', playerId)
        .eq('intento', 1);

    final results = (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(CombineResult.fromMap)
        .toList();
    return {for (final result in results) result.testId: result};
  }

  Future<void> upsertPlayerResults({
    required String sessionId,
    required String playerId,
    required List<CombineResultInput> results,
  }) async {
    if (results.isEmpty) return;
    final payload = results
        .map(
          (result) => {
            'session_id': sessionId,
            'player_id': playerId,
            ...result.toMap(),
          },
        )
        .toList();

    await _client.from('combine_results').upsert(
          payload,
          onConflict: 'session_id,player_id,test_id,intento',
        );
  }

  Future<List<CombineRankingRow>> listRankings({
    required String sessionId,
    required String testId,
  }) async {
    final data = await _client
        .from('combine_results')
        .select(
            'player_id, valor, players(jersey_number, first_name, last_name, jersey_name), combine_tests(codigo, nombre, unidad)')
        .eq('session_id', sessionId)
        .eq('test_id', testId)
        .eq('intento', 1);

    final rows = (data as List<dynamic>).cast<Map<String, dynamic>>();
    return rows.map((row) {
      final player = row['players'] as Map<String, dynamic>?;
      final test = row['combine_tests'] as Map<String, dynamic>?;
      final firstName = (player?['first_name'] as String? ?? '').trim();
      final lastName = (player?['last_name'] as String? ?? '').trim();
      final jerseyName = (player?['jersey_name'] as String?)?.trim();
      return CombineRankingRow(
        playerId: row['player_id'] as String,
        jerseyNumber: (player?['jersey_number'] as num?)?.toInt(),
        nombre: '$firstName $lastName'.trim(),
        jerseyName: jerseyName?.isEmpty == true ? null : jerseyName,
        valor: _parseNumeric(row['valor']),
        unidad: (test?['unidad'] as String? ?? '').trim(),
        testId: testId,
        testCode: (test?['codigo'] as String?)?.trim(),
        testNombre: (test?['nombre'] as String?)?.trim(),
      );
    }).toList();
  }

  Future<List<CombineAthleticRankRow>> listAthleticIndex({
    required String sessionId,
  }) async {
    final data = await _client
        .from('combine_results')
        .select(
            'player_id, test_id, valor, players(jersey_number, first_name, last_name, jersey_name), combine_tests(codigo, nombre, unidad, mejor)')
        .eq('session_id', sessionId)
        .eq('intento', 1);

    final rows = (data as List<dynamic>).cast<Map<String, dynamic>>();
    final rankingRows = rows.map((row) {
      final player = row['players'] as Map<String, dynamic>?;
      final test = row['combine_tests'] as Map<String, dynamic>?;
      final firstName = (player?['first_name'] as String? ?? '').trim();
      final lastName = (player?['last_name'] as String? ?? '').trim();
      final jerseyName = (player?['jersey_name'] as String?)?.trim();
      return CombineRankingRow(
        playerId: row['player_id'] as String,
        jerseyNumber: (player?['jersey_number'] as num?)?.toInt(),
        nombre: '$firstName $lastName'.trim(),
        jerseyName: jerseyName?.isEmpty == true ? null : jerseyName,
        valor: _parseNumeric(row['valor']),
        unidad: (test?['unidad'] as String? ?? '').trim(),
        testId: row['test_id'] as String?,
        testCode: (test?['codigo'] as String?)?.trim(),
        testNombre: (test?['nombre'] as String?)?.trim(),
      );
    }).toList();

    return calculateCombineAthleticIndexRows(rows: rankingRows);
  }

  static double _parseNumeric(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
