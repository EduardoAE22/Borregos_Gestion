import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/game_plays_repo.dart';
import '../data/games_repo.dart';
import '../domain/game_play.dart';
import 'games_providers.dart';

final gamePlaysRepoProvider = Provider<GamePlaysRepo>((ref) {
  return GamePlaysRepo(Supabase.instance.client);
});

final gamePlaybookControllerProvider = AsyncNotifierProvider.family<
    GamePlaybookController, List<GamePlay>, String>(
  GamePlaybookController.new,
);

class GamePlaybookController
    extends FamilyAsyncNotifier<List<GamePlay>, String> {
  late final String _gameId;

  GamePlaysRepo get _playsRepo => ref.read(gamePlaysRepoProvider);
  GamesRepo get _gamesRepo => ref.read(gamesRepoProvider);

  @override
  Future<List<GamePlay>> build(String arg) async {
    _gameId = arg;
    return _playsRepo.listByGameId(_gameId);
  }

  Future<void> addPlay({
    required GamePlay play,
    required bool pointsForOur,
  }) async {
    final created = await _playsRepo.addPlay(play);
    final current = state.valueOrNull ?? const <GamePlay>[];
    final game = await ref.read(gameByIdProvider(_gameId).future);
    final baselineOur = game?.ourScore ?? 0;
    final baselineOpp = game?.oppScore ?? 0;
    final result = applyPlayMutation(
      currentPlays: current,
      createdPlay: created,
      currentOurScore: baselineOur,
      currentOppScore: baselineOpp,
      pointsForOur: pointsForOur,
    );
    state = AsyncData(result.nextPlays);

    if (created.points > 0) {
      if (game != null) {
        await _gamesRepo.updateScore(
            _gameId, result.nextOurScore, result.nextOppScore);
      }
      ref.invalidate(gameByIdProvider(_gameId));
    }
  }

  Future<void> deletePlay(String playId) async {
    await _playsRepo.deletePlay(playId);
    final current = state.valueOrNull ?? const <GamePlay>[];
    state = AsyncData(current.where((p) => p.id != playId).toList());
  }
}

class GamePlayStats {
  const GamePlayStats({
    required this.qbCompletions,
    required this.qbAttempts,
    required this.receptions,
    required this.targets,
    required this.drops,
    required this.receivingYards,
    required this.defInterceptions,
    required this.tackleFlags,
    required this.sacks,
  });

  final Map<String, int> qbCompletions;
  final Map<String, int> qbAttempts;
  final Map<String, int> receptions;
  final Map<String, int> targets;
  final Map<String, int> drops;
  final Map<String, int> receivingYards;
  final Map<String, int> defInterceptions;
  final Map<String, int> tackleFlags;
  final Map<String, int> sacks;
}

GamePlayStats buildGamePlayStats(List<GamePlay> plays) {
  void inc(Map<String, int> map, String? key, [int delta = 1]) {
    if (key == null || key.trim().isEmpty) return;
    map.update(key, (value) => value + delta, ifAbsent: () => delta);
  }

  final qbCompletions = <String, int>{};
  final qbAttempts = <String, int>{};
  final receptions = <String, int>{};
  final targets = <String, int>{};
  final drops = <String, int>{};
  final receivingYards = <String, int>{};
  final defInterceptions = <String, int>{};
  final tackleFlags = <String, int>{};
  final sacks = <String, int>{};

  for (final play in plays) {
    if (play.unit == 'ofensiva') {
      final qbKey = play.qbName ?? play.qbPlayerId;
      final recvKey = play.receiverName ?? play.receiverPlayerId;
      if (play.isTarget) inc(qbAttempts, qbKey);
      if (play.isCompletion) inc(qbCompletions, qbKey);
      if (play.isTarget) inc(targets, recvKey);
      if (play.isCompletion) {
        inc(receptions, recvKey);
        inc(receivingYards, recvKey, play.yards);
      }
      if (play.isDrop) inc(drops, recvKey);
      continue;
    }

    final defKey = play.defenderName ?? play.defenderPlayerId;
    if (play.isInterception) inc(defInterceptions, defKey);
    if (play.isTackleFlag) inc(tackleFlags, defKey);
    if (play.isSack) inc(sacks, defKey);
  }

  return GamePlayStats(
    qbCompletions: qbCompletions,
    qbAttempts: qbAttempts,
    receptions: receptions,
    targets: targets,
    drops: drops,
    receivingYards: receivingYards,
    defInterceptions: defInterceptions,
    tackleFlags: tackleFlags,
    sacks: sacks,
  );
}

final gamePlayStatsProvider =
    Provider.family<GamePlayStats, List<GamePlay>>((ref, plays) {
  return buildGamePlayStats(plays);
});

class PlayMutationResult {
  const PlayMutationResult({
    required this.nextPlays,
    required this.nextOurScore,
    required this.nextOppScore,
  });

  final List<GamePlay> nextPlays;
  final int nextOurScore;
  final int nextOppScore;
}

PlayMutationResult applyPlayMutation({
  required List<GamePlay> currentPlays,
  required GamePlay createdPlay,
  required int currentOurScore,
  required int currentOppScore,
  required bool pointsForOur,
}) {
  final nextPlays = <GamePlay>[createdPlay, ...currentPlays];
  final nextOur = createdPlay.points > 0 && pointsForOur
      ? currentOurScore + createdPlay.points
      : currentOurScore;
  final nextOpp = createdPlay.points > 0 && !pointsForOur
      ? currentOppScore + createdPlay.points
      : currentOppScore;

  return PlayMutationResult(
    nextPlays: nextPlays,
    nextOurScore: nextOur,
    nextOppScore: nextOpp,
  );
}
