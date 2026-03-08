import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../seasons/providers/seasons_providers.dart';
import '../data/combine_repo.dart';
import '../domain/combine.dart';

final combineRepoProvider = Provider<CombineRepo>((ref) {
  return CombineRepo(Supabase.instance.client);
});

final combineSessionsByActiveSeasonProvider =
    FutureProvider<List<CombineSession>>((ref) async {
  final season = await ref.watch(activeSeasonProvider.future);
  if (season == null) return const <CombineSession>[];
  return ref.read(combineRepoProvider).listSessions(season.id);
});

final combineTestsProvider = FutureProvider<List<CombineTest>>((ref) async {
  return ref.read(combineRepoProvider).listTests();
});

final combinePlayerResultsProvider = FutureProvider.family<
    Map<String, CombineResult>, ({String sessionId, String playerId})>(
  (ref, args) async {
    return ref.read(combineRepoProvider).getPlayerResults(
          sessionId: args.sessionId,
          playerId: args.playerId,
        );
  },
);

final combineRankingsProvider = FutureProvider.family<List<CombineRankingRow>,
    ({String sessionId, String testId})>(
  (ref, args) async {
    return ref.read(combineRepoProvider).listRankings(
          sessionId: args.sessionId,
          testId: args.testId,
        );
  },
);

final combineAthleticIndexProvider =
    FutureProvider.family<List<CombineAthleticRankRow>, String>(
  (ref, sessionId) async {
    return ref.read(combineRepoProvider).listAthleticIndex(
          sessionId: sessionId,
        );
  },
);
