import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../players/domain/player.dart';
import '../data/uniforms_repo.dart';
import '../domain/uniform_extra.dart';

final uniformsRepoProvider = Provider<UniformsRepo>((ref) {
  return UniformsRepo(Supabase.instance.client);
});

final uniformsActivePlayersBySeasonProvider =
    FutureProvider.family<List<Player>, String>((ref, seasonId) async {
  return ref.read(uniformsRepoProvider).listActivePlayersForSeason(seasonId);
});

final uniformsExtrasBySeasonProvider =
    FutureProvider.family<List<UniformExtra>, String>((ref, seasonId) async {
  return ref.read(uniformsRepoProvider).listExtrasBySeason(seasonId);
});
