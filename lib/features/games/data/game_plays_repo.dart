import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/game_play.dart';

class GamePlaysRepo {
  GamePlaysRepo(this._client);

  final SupabaseClient _client;

  Future<List<GamePlay>> listByGameId(String gameId) async {
    final data = await _client
        .from('game_plays')
        .select(
          'id, game_id, created_at, half, unit, down, distance_yards, yards, points, description, notes, '
          'qb_player_id, receiver_player_id, is_target, is_completion, is_drop, is_pass_td, is_rush, is_rush_td, '
          'defender_player_id, is_sack, is_tackle_flag, is_interception, is_pick6, is_pass_defended, is_penalty, penalty_text, '
          'qb_player:players!game_plays_qb_player_id_fkey(first_name,last_name,jersey_number), '
          'receiver_player:players!game_plays_receiver_player_id_fkey(first_name,last_name,jersey_number), '
          'defender_player:players!game_plays_defender_player_id_fkey(first_name,last_name,jersey_number)',
        )
        .eq('game_id', gameId)
        .order('created_at', ascending: false);

    return (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(GamePlay.fromMap)
        .toList();
  }

  Future<GamePlay> addPlay(GamePlay play) async {
    if (play.gameId.trim().isEmpty) {
      throw const FormatException('game_id es requerido para guardar jugadas.');
    }

    final created = await _client
        .from('game_plays')
        .insert(play.toMap())
        .select(
          'id, game_id, created_at, half, unit, down, distance_yards, yards, points, description, notes, '
          'qb_player_id, receiver_player_id, is_target, is_completion, is_drop, is_pass_td, is_rush, is_rush_td, '
          'defender_player_id, is_sack, is_tackle_flag, is_interception, is_pick6, is_pass_defended, is_penalty, penalty_text, '
          'qb_player:players!game_plays_qb_player_id_fkey(first_name,last_name,jersey_number), '
          'receiver_player:players!game_plays_receiver_player_id_fkey(first_name,last_name,jersey_number), '
          'defender_player:players!game_plays_defender_player_id_fkey(first_name,last_name,jersey_number)',
        )
        .single();

    return GamePlay.fromMap(created);
  }

  Future<void> deletePlay(String playId) async {
    await _client.from('game_plays').delete().eq('id', playId);
  }

  Future<List<Map<String, dynamic>>> listPlayerPlaysWithGames(
      String playerId) async {
    final data = await _client
        .from('game_plays')
        .select(
          'id, game_id, half, unit, yards, points, is_target, is_completion, is_drop, '
          'is_pass_td, is_rush, is_rush_td, is_interception, is_pick6, is_pass_defended, '
          'is_sack, is_tackle_flag, qb_player_id, receiver_player_id, defender_player_id, created_at, '
          'games(id, season_id, roster_season_id, opponent, game_date, game_type, our_score, opp_score)',
        )
        .or('qb_player_id.eq.$playerId,receiver_player_id.eq.$playerId,defender_player_id.eq.$playerId')
        .order('created_at', ascending: false);

    return (data as List<dynamic>).cast<Map<String, dynamic>>();
  }
}
