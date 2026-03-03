import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/award.dart';

class AwardsRepo {
  AwardsRepo(this._client);

  final SupabaseClient _client;

  Future<List<Award>> listAwards(String seasonId) async {
    final data = await _client
        .from('awards_player_month')
        .select(
          'id, season_id, month, player_id, reason, created_at, '
          'players(first_name,last_name,jersey_number)',
        )
        .eq('season_id', seasonId)
        .order('month', ascending: false);

    return (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Award.fromMap)
        .toList();
  }

  Future<void> upsertAward({
    required String seasonId,
    required DateTime monthDateFirstDay,
    required String playerId,
    String? reason,
  }) async {
    final normalized = normalizeMonth(monthDateFirstDay);
    final monthIso = _asDate(normalized);

    await _client.from('awards_player_month').upsert(
      {
        'season_id': seasonId,
        'month': monthIso,
        'player_id': playerId,
        'reason': reason,
      },
      onConflict: 'season_id,month',
    );
  }

  Future<List<AwardPlayerOption>> listSeasonPlayers(String seasonId) async {
    final data = await _client
        .from('players')
        .select('id, jersey_number, first_name, last_name')
        .eq('season_id', seasonId)
        .eq('is_active', true)
        .order('jersey_number', ascending: true);

    return (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(AwardPlayerOption.fromMap)
        .toList();
  }

  static DateTime normalizeMonth(DateTime input) =>
      DateTime(input.year, input.month, 1);

  static String _asDate(DateTime date) =>
      DateTime(date.year, date.month, date.day)
          .toIso8601String()
          .split('T')
          .first;
}
