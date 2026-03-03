import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../seasons/domain/season.dart';
import '../../seasons/providers/seasons_providers.dart';
import '../data/players_repo.dart';
import '../domain/player.dart';
import '../domain/player_metric.dart';

final playersRepoProvider = Provider<PlayersRepo>((ref) {
  return PlayersRepo(Supabase.instance.client);
});

final playersByActiveSeasonProvider = FutureProvider<List<Player>>((ref) async {
  final seasonId = ref.watch(activeSeasonIdProvider);
  if (seasonId == null) return [];
  return ref.read(playersRepoProvider).listPlayers(seasonId);
});

final playersBySeasonProvider =
    FutureProvider.family<List<Player>, String>((ref, seasonId) async {
  return ref.read(playersRepoProvider).listPlayers(seasonId);
});

typedef ActiveSeasonPlayersBundle = ({Season? season, List<Player> players});

final activeSeasonPlayersBundleProvider =
    FutureProvider<ActiveSeasonPlayersBundle>((ref) async {
  final season = await ref.watch(activeSeasonProvider.future);
  if (season == null) {
    return (season: null, players: const <Player>[]);
  }

  final players = await ref.read(playersRepoProvider).listPlayers(season.id);
  return (season: season, players: players);
});

final playerByIdProvider =
    FutureProvider.family<Player?, String>((ref, playerId) {
  return ref.read(playersRepoProvider).getPlayer(playerId);
});

final playerMetricsProvider =
    FutureProvider.family<List<PlayerMetric>, String>((ref, playerId) {
  return ref.read(playersRepoProvider).listMetrics(playerId);
});
