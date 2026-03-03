import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/stats.dart';

class StatsRepo {
  StatsRepo(this._client);

  final SupabaseClient _client;

  Future<List<RosterPlayer>> listRoster(String seasonId) async {
    final data = await _client
        .from('players')
        .select('id, jersey_number, first_name, last_name')
        .eq('season_id', seasonId)
        .eq('is_active', true)
        .order('jersey_number', ascending: true);

    return (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(RosterPlayer.fromMap)
        .toList();
  }

  Future<List<QBStat>> getQBStats(String gameId) async {
    final data = await _client
        .from('game_stats_qb')
        .select(
            'game_id, player_id, completions, incompletions, pass_tds, interceptions, rush_tds, players(first_name,last_name,jersey_number)')
        .eq('game_id', gameId)
        .order('created_at', ascending: false);

    return (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(QBStat.fromMap)
        .toList();
  }

  Future<void> upsertQBStat({
    required String gameId,
    required String playerId,
    required int completions,
    required int incompletions,
    required int passTds,
    required int interceptions,
    required int rushTds,
  }) async {
    await _client.from('game_stats_qb').upsert({
      'game_id': gameId,
      'player_id': playerId,
      'completions': completions,
      'incompletions': incompletions,
      'pass_tds': passTds,
      'interceptions': interceptions,
      'rush_tds': rushTds,
    }, onConflict: 'game_id,player_id');
  }

  Future<List<SkillStat>> getSkillStats(String gameId) async {
    final data = await _client
        .from('game_stats_skill')
        .select(
            'game_id, player_id, receptions, targets, rec_yards, rec_tds, drops, players(first_name,last_name,jersey_number)')
        .eq('game_id', gameId)
        .order('created_at', ascending: false);

    return (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(SkillStat.fromMap)
        .toList();
  }

  Future<void> upsertSkillStat({
    required String gameId,
    required String playerId,
    required int receptions,
    required int targets,
    required int recYards,
    required int recTds,
    required int drops,
  }) async {
    await _client.from('game_stats_skill').upsert({
      'game_id': gameId,
      'player_id': playerId,
      'receptions': receptions,
      'targets': targets,
      'rec_yards': recYards,
      'rec_tds': recTds,
      'drops': drops,
    }, onConflict: 'game_id,player_id');
  }

  Future<List<DefStat>> getDefStats(String gameId) async {
    final data = await _client
        .from('game_stats_def')
        .select(
            'game_id, player_id, tackles, sacks, interceptions, pick6, flags, players(first_name,last_name,jersey_number)')
        .eq('game_id', gameId)
        .order('created_at', ascending: false);

    return (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(DefStat.fromMap)
        .toList();
  }

  Future<void> upsertDefStat({
    required String gameId,
    required String playerId,
    required int tackles,
    required int sacks,
    required int interceptions,
    required int pick6,
    required int flags,
  }) async {
    await _client.from('game_stats_def').upsert({
      'game_id': gameId,
      'player_id': playerId,
      'tackles': tackles,
      'sacks': sacks,
      'interceptions': interceptions,
      'pick6': pick6,
      'flags': flags,
    }, onConflict: 'game_id,player_id');
  }
}
