import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/seasons_repo.dart';
import '../domain/season.dart';

typedef SetActiveSeasonAction = Future<void> Function(String seasonId);

final seasonsRepoProvider = Provider<SeasonsRepo>((ref) {
  return SeasonsRepo(Supabase.instance.client);
});

final seasonsListProvider = FutureProvider<List<Season>>((ref) async {
  return ref.read(seasonsRepoProvider).listSeasons();
});

final activeSeasonProvider = FutureProvider<Season?>((ref) async {
  return ref.read(seasonsRepoProvider).getActiveSeason();
});

final activeSeasonIdProvider = Provider<String?>((ref) {
  return ref.watch(activeSeasonProvider).valueOrNull?.id;
});

final setActiveSeasonActionProvider = Provider<SetActiveSeasonAction>((ref) {
  return (seasonId) async {
    await ref.read(seasonsRepoProvider).setActiveSeason(seasonId);
    ref.invalidate(activeSeasonProvider);
    ref.invalidate(seasonsListProvider);
  };
});
