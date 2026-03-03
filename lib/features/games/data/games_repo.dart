import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/logger.dart';
import '../domain/game.dart';

class GamesRepo {
  GamesRepo(this._client);

  final SupabaseClient _client;

  Future<List<Game>> listTournamentGamesBySeason(String seasonId) async {
    final stopwatch = Stopwatch()..start();
    final data = await _client
        .from('games')
        .select()
        .eq('season_id', seasonId)
        .eq('game_type', 'torneo')
        .order('game_date', ascending: true);
    stopwatch.stop();
    AppLogger.perf('GamesRepo.listTournamentGamesBySeason',
        elapsed: stopwatch.elapsed, detail: 'season=$seasonId');

    return (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Game.fromMap)
        .toList();
  }

  Future<List<Game>> getTournamentGamesBySeason(String seasonId) {
    return listTournamentGamesBySeason(seasonId);
  }

  Future<List<Game>> listGlobalGamesByType(String gameType) async {
    final stopwatch = Stopwatch()..start();
    final data = await _client
        .from('games')
        .select()
        .isFilter('season_id', null)
        .eq('game_type', gameType)
        .order('game_date', ascending: true);
    stopwatch.stop();
    AppLogger.perf('GamesRepo.listGlobalGamesByType',
        elapsed: stopwatch.elapsed, detail: 'type=$gameType');

    return (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Game.fromMap)
        .toList();
  }

  Future<List<Game>> getFriendlies() {
    return listGlobalGamesByType('amistoso');
  }

  Future<List<Game>> getInternalGames() {
    return listGlobalGamesByType('interno');
  }

  Future<Game?> getGame(String id) async {
    final stopwatch = Stopwatch()..start();
    final data =
        await _client.from('games').select().eq('id', id).maybeSingle();
    stopwatch.stop();
    AppLogger.perf('GamesRepo.getGame',
        elapsed: stopwatch.elapsed, detail: 'id=$id');
    if (data == null) return null;
    return Game.fromMap(data);
  }

  Future<Game> upsertGame(Game game) async {
    if (game.id == null) {
      final created =
          await _client.from('games').insert(game.toMap()).select().single();
      return Game.fromMap(created);
    }

    final updated = await _client
        .from('games')
        .update(game.toMap())
        .eq('id', game.id!)
        .select()
        .single();

    return Game.fromMap(updated);
  }

  Future<Game> createGameTournament({
    required String seasonId,
    required String opponent,
    required DateTime gameDate,
    String? location,
  }) {
    return upsertGame(
      Game(
        seasonId: seasonId,
        opponent: opponent,
        gameDate: gameDate,
        gameType: 'torneo',
        location: location,
        isTournament: true,
      ),
    );
  }

  Future<Game> createGameFriendly({
    required String opponent,
    required DateTime gameDate,
    required String rosterSeasonId,
    String? location,
  }) {
    return upsertGame(
      Game(
        seasonId: null,
        rosterSeasonId: rosterSeasonId,
        opponent: opponent,
        gameDate: gameDate,
        gameType: 'amistoso',
        location: location,
        isTournament: false,
      ),
    );
  }

  Future<Game> createGameInternal({
    required DateTime gameDate,
    required String rosterSeasonId,
    String opponent = 'Interno A vs Interno B',
  }) {
    return upsertGame(
      Game(
        seasonId: null,
        rosterSeasonId: rosterSeasonId,
        opponent: opponent,
        gameDate: gameDate,
        gameType: 'interno',
        location: null,
        isTournament: false,
      ),
    );
  }

  Future<void> updateScore(String gameId, int our, int opp) async {
    await _client
        .from('games')
        .update({'our_score': our, 'opp_score': opp}).eq('id', gameId);
  }

  Future<void> deleteGame(String gameId) async {
    await _client.from('games').delete().eq('id', gameId);
  }
}
