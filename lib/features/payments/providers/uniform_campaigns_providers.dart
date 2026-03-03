import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../seasons/providers/seasons_providers.dart';
import '../data/uniform_campaigns_repo.dart';
import '../domain/uniform_campaign.dart';

final uniformCampaignsRepoProvider = Provider<UniformCampaignsRepo>((ref) {
  return UniformCampaignsRepo(Supabase.instance.client);
});

final uniformCampaignsByActiveSeasonProvider =
    FutureProvider<List<UniformCampaign>>((ref) async {
  final season = await ref.watch(activeSeasonProvider.future);
  if (season == null) return const <UniformCampaign>[];
  return ref.read(uniformCampaignsRepoProvider).listBySeason(season.id);
});
