import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../seasons/providers/seasons_providers.dart';
import '../data/awards_repo.dart';
import '../domain/award.dart';

final awardsRepoProvider = Provider<AwardsRepo>((ref) {
  return AwardsRepo(Supabase.instance.client);
});

final awardsListProvider =
    FutureProvider.family<List<Award>, String>((ref, seasonId) async {
  return ref.read(awardsRepoProvider).listAwards(seasonId);
});

final awardPlayersProvider =
    FutureProvider.family<List<AwardPlayerOption>, String>(
        (ref, seasonId) async {
  return ref.read(awardsRepoProvider).listSeasonPlayers(seasonId);
});

final awardsByActiveSeasonProvider = FutureProvider<List<Award>>((ref) async {
  final seasonId = ref.watch(activeSeasonIdProvider);
  if (seasonId == null) return [];
  return ref.read(awardsRepoProvider).listAwards(seasonId);
});
