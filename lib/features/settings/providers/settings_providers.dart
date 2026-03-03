import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/settings_repo.dart';

final settingsRepoProvider = Provider<SettingsRepo>((ref) {
  return SettingsRepo(Supabase.instance.client);
});

final weeklyFeeAmountProvider = FutureProvider<double>((ref) async {
  return ref.read(settingsRepoProvider).getWeeklyFeeAmount();
});
