import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/season.dart';

class SeasonsRepo {
  SeasonsRepo(this._client);

  final SupabaseClient _client;

  Future<List<Season>> listSeasons() async {
    final data = await _client
        .from('seasons')
        .select('id, name, starts_on, ends_on, is_active')
        .order('created_at', ascending: false);

    return (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Season.fromMap)
        .toList();
  }

  Future<Season?> getActiveSeason() async {
    final data = await _client
        .from('seasons')
        .select('id, name, starts_on, ends_on, is_active')
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (data == null) return null;
    return Season.fromMap(data);
  }

  Future<void> setActiveSeason(String seasonId) async {
    await _client.rpc('set_active_season', params: {'p_season_id': seasonId});
  }

  Future<Season> createSeason(SeasonCreate payload) async {
    final created = await _client
        .from('seasons')
        .insert(payload.toMap())
        .select('id, name, starts_on, ends_on, is_active')
        .single();

    return Season.fromMap(created);
  }

  Future<void> deleteSeason(String seasonId) async {
    await _client.from('seasons').delete().eq('id', seasonId);
  }
}
