import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../seasons/providers/seasons_providers.dart';
import '../data/games_repo.dart';
import '../data/stats_repo.dart';
import '../domain/game.dart';
import '../domain/stats.dart';

final gamesRepoProvider = Provider<GamesRepo>((ref) {
  return GamesRepo(Supabase.instance.client);
});

final statsRepoProvider = Provider<StatsRepo>((ref) {
  return StatsRepo(Supabase.instance.client);
});

final gamesByActiveSeasonProvider = FutureProvider<List<Game>>((ref) async {
  final seasonId = ref.watch(activeSeasonIdProvider);
  if (seasonId == null) return [];
  return ref.read(gamesRepoProvider).getTournamentGamesBySeason(seasonId);
});

final tournamentGamesBySeasonProvider =
    FutureProvider.family<List<Game>, String>((ref, seasonId) async {
  return ref.read(gamesRepoProvider).getTournamentGamesBySeason(seasonId);
});

final globalGamesByTypeProvider =
    FutureProvider.family<List<Game>, String>((ref, gameType) async {
  if (gameType == 'interno') {
    return ref.read(gamesRepoProvider).getInternalGames();
  }
  return ref.read(gamesRepoProvider).getFriendlies();
});

final gameByIdProvider = FutureProvider.family<Game?, String>((ref, gameId) {
  return ref.read(gamesRepoProvider).getGame(gameId);
});

final rosterBySeasonProvider =
    FutureProvider.family<List<RosterPlayer>, String>((ref, seasonId) {
  return ref.read(statsRepoProvider).listRoster(seasonId);
});

final qbStatsProvider =
    FutureProvider.family<List<QBStat>, String>((ref, gameId) {
  return ref.read(statsRepoProvider).getQBStats(gameId);
});

final skillStatsProvider =
    FutureProvider.family<List<SkillStat>, String>((ref, gameId) {
  return ref.read(statsRepoProvider).getSkillStats(gameId);
});

final defStatsProvider =
    FutureProvider.family<List<DefStat>, String>((ref, gameId) {
  return ref.read(statsRepoProvider).getDefStats(gameId);
});
