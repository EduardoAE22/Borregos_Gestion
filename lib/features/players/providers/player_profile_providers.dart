import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../games/providers/game_plays_provider.dart';
import '../../seasons/providers/seasons_providers.dart';

class PlayerSeasonStats {
  const PlayerSeasonStats({
    this.passCompletions = 0,
    this.passAttempts = 0,
    this.passYards = 0,
    this.passTds = 0,
    this.interceptionsThrown = 0,
    this.targets = 0,
    this.receptions = 0,
    this.drops = 0,
    this.recYards = 0,
    this.recTds = 0,
    this.defInterceptions = 0,
    this.pick6 = 0,
    this.sacks = 0,
    this.pressures = 0,
    this.flagsPulled = 0,
    this.passesDefended = 0,
  });

  final int passCompletions;
  final int passAttempts;
  final int passYards;
  final int passTds;
  final int interceptionsThrown;
  final int targets;
  final int receptions;
  final int drops;
  final int recYards;
  final int recTds;
  final int defInterceptions;
  final int pick6;
  final int sacks;
  final int pressures;
  final int flagsPulled;
  final int passesDefended;
}

class PlayerGameLogRow {
  const PlayerGameLogRow({
    required this.gameId,
    required this.date,
    required this.opponent,
    required this.gameType,
    required this.ourScore,
    required this.oppScore,
    required this.plays,
    required this.yards,
    required this.targets,
    required this.receptions,
    required this.tds,
    required this.sacks,
    required this.interceptions,
    required this.flags,
  });

  final String gameId;
  final DateTime date;
  final String opponent;
  final String gameType;
  final int ourScore;
  final int oppScore;
  final int plays;
  final int yards;
  final int targets;
  final int receptions;
  final int tds;
  final int sacks;
  final int interceptions;
  final int flags;

  String get result =>
      ourScore > oppScore ? 'W' : (ourScore < oppScore ? 'L' : 'E');
}

final _playerPlayRowsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, playerId) async {
  final fetcher = ref.read(playerPlayRowsFetcherProvider);
  return fetcher(playerId);
});

typedef PlayerPlayRowsFetcher = Future<List<Map<String, dynamic>>> Function(
    String playerId);

final playerPlayRowsFetcherProvider = Provider<PlayerPlayRowsFetcher>((ref) {
  return ref.read(gamePlaysRepoProvider).listPlayerPlaysWithGames;
});

bool matchesActiveSeasonGame(
  Map<String, dynamic>? game,
  String activeSeasonId,
) {
  if (game == null) return false;
  final seasonId = _asNullableString(game['season_id']);
  final rosterSeasonId = _asNullableString(game['roster_season_id']);

  if (seasonId != null) {
    return seasonId == activeSeasonId;
  }
  if (rosterSeasonId != null) {
    return rosterSeasonId == activeSeasonId;
  }

  // Fallback para datos legacy: si ambos vienen null, se considera activo.
  return true;
}

String? _asNullableString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

final playerSeasonStatsProvider =
    FutureProvider.family<PlayerSeasonStats, String>((ref, playerId) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (!(profile?.canWriteGeneral ?? false)) return const PlayerSeasonStats();

  final activeSeason = await ref.watch(activeSeasonProvider.future);
  if (activeSeason == null) return const PlayerSeasonStats();

  final rows = await ref.watch(_playerPlayRowsProvider(playerId).future);
  final seasonRows = rows.where((row) {
    final game = row['games'] as Map<String, dynamic>?;
    return matchesActiveSeasonGame(game, activeSeason.id);
  });

  var passCompletions = 0;
  var passAttempts = 0;
  var passYards = 0;
  var passTds = 0;
  var interceptionsThrown = 0;
  var targets = 0;
  var receptions = 0;
  var drops = 0;
  var recYards = 0;
  var recTds = 0;
  var defInterceptions = 0;
  var pick6 = 0;
  var sacks = 0;
  var flagsPulled = 0;
  var passesDefended = 0;

  for (final row in seasonRows) {
    final yards = (row['yards'] as num?)?.toInt() ?? 0;
    final isTarget = (row['is_target'] as bool?) ?? false;
    final isCompletion = (row['is_completion'] as bool?) ?? false;
    final isDrop = (row['is_drop'] as bool?) ?? false;
    final isPassTd = (row['is_pass_td'] as bool?) ?? false;
    final isRushTd = (row['is_rush_td'] as bool?) ?? false;
    final isInterception = (row['is_interception'] as bool?) ?? false;
    final isPick6 = (row['is_pick6'] as bool?) ?? false;
    final isSack = (row['is_sack'] as bool?) ?? false;
    final isTackleFlag = (row['is_tackle_flag'] as bool?) ?? false;
    final isPassDefended = (row['is_pass_defended'] as bool?) ?? false;
    final unit = (row['unit'] as String?) ?? '';
    final qbPlayerId = row['qb_player_id'] as String?;
    final receiverPlayerId = row['receiver_player_id'] as String?;
    final defenderPlayerId = row['defender_player_id'] as String?;

    if (qbPlayerId == playerId) {
      if (isTarget) passAttempts++;
      if (isCompletion) {
        passCompletions++;
        passYards += yards;
      }
      if (isPassTd) passTds++;
      if (unit == 'ofensiva' && isInterception) interceptionsThrown++;
    }

    if (receiverPlayerId == playerId) {
      if (isTarget) targets++;
      if (isCompletion) {
        receptions++;
        recYards += yards;
      }
      if (isDrop) drops++;
      if (isPassTd || isRushTd) recTds++;
    }

    if (defenderPlayerId == playerId) {
      if (isInterception) defInterceptions++;
      if (isPick6) pick6++;
      if (isSack) sacks++;
      if (isTackleFlag) flagsPulled++;
      if (isPassDefended) passesDefended++;
    }
  }

  return PlayerSeasonStats(
    passCompletions: passCompletions,
    passAttempts: passAttempts,
    passYards: passYards,
    passTds: passTds,
    interceptionsThrown: interceptionsThrown,
    targets: targets,
    receptions: receptions,
    drops: drops,
    recYards: recYards,
    recTds: recTds,
    defInterceptions: defInterceptions,
    pick6: pick6,
    sacks: sacks,
    pressures: 0,
    flagsPulled: flagsPulled,
    passesDefended: passesDefended,
  );
});

final playerGameLogProvider =
    FutureProvider.family<List<PlayerGameLogRow>, String>(
        (ref, playerId) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (!(profile?.canWriteGeneral ?? false)) return const <PlayerGameLogRow>[];

  final activeSeason = await ref.watch(activeSeasonProvider.future);
  if (activeSeason == null) return const <PlayerGameLogRow>[];

  final rows = await ref.watch(_playerPlayRowsProvider(playerId).future);
  final grouped = <String, List<Map<String, dynamic>>>{};
  for (final row in rows) {
    final game = row['games'] as Map<String, dynamic>?;
    final gameId = game?['id'] as String?;
    if (gameId == null) continue;

    if (!matchesActiveSeasonGame(game, activeSeason.id)) continue;

    grouped.putIfAbsent(gameId, () => <Map<String, dynamic>>[]).add(row);
  }

  final out = <PlayerGameLogRow>[];
  for (final entry in grouped.entries) {
    final first = entry.value.first;
    final game = first['games'] as Map<String, dynamic>;
    var plays = 0;
    var yards = 0;
    var targets = 0;
    var receptions = 0;
    var tds = 0;
    var sacks = 0;
    var interceptions = 0;
    var flags = 0;

    for (final row in entry.value) {
      final rowYards = (row['yards'] as num?)?.toInt() ?? 0;
      final isTarget = (row['is_target'] as bool?) ?? false;
      final isCompletion = (row['is_completion'] as bool?) ?? false;
      final isPassTd = (row['is_pass_td'] as bool?) ?? false;
      final isRushTd = (row['is_rush_td'] as bool?) ?? false;
      final isSack = (row['is_sack'] as bool?) ?? false;
      final isInterception = (row['is_interception'] as bool?) ?? false;
      final isTackleFlag = (row['is_tackle_flag'] as bool?) ?? false;
      plays++;
      yards += rowYards;
      if (isTarget) targets++;
      if (isCompletion) receptions++;
      if (isPassTd || isRushTd) tds++;
      if (isSack) sacks++;
      if (isInterception) interceptions++;
      if (isTackleFlag) flags++;
    }

    out.add(
      PlayerGameLogRow(
        gameId: entry.key,
        date: DateTime.parse(game['game_date'] as String),
        opponent: (game['opponent'] as String?) ?? '-',
        gameType: (game['game_type'] as String?) ?? 'torneo',
        ourScore: (game['our_score'] as num?)?.toInt() ?? 0,
        oppScore: (game['opp_score'] as num?)?.toInt() ?? 0,
        plays: plays,
        yards: yards,
        targets: targets,
        receptions: receptions,
        tds: tds,
        sacks: sacks,
        interceptions: interceptions,
        flags: flags,
      ),
    );
  }

  out.sort((a, b) => b.date.compareTo(a.date));
  return out;
});
