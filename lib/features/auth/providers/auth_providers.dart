import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repo.dart';

class AppProfile {
  const AppProfile({
    required this.id,
    required this.fullName,
    required this.role,
  });

  final String id;
  final String fullName;
  final String role;

  bool get isSuperAdmin => role == 'super_admin';
  bool get isCoach => role == 'coach';
  bool get isViewer => role == 'viewer';

  bool get canWriteGeneral => isSuperAdmin || isCoach;
  bool get canWritePayments => isSuperAdmin || isCoach;
}

final authRepoProvider = Provider<AuthRepo>((ref) {
  return AuthRepo(Supabase.instance.client);
});

final authStateChangesProvider = StreamProvider<User?>((ref) {
  final repo = ref.watch(authRepoProvider);
  return repo.currentUserStream();
});

final currentProfileProvider = FutureProvider<AppProfile?>((ref) async {
  ref.watch(authStateChangesProvider);
  final repo = ref.read(authRepoProvider);
  final user = repo.currentUser;
  if (user == null) return null;

  final data = await Supabase.instance.client
      .from('profiles')
      .select('id, full_name, role')
      .eq('id', user.id)
      .maybeSingle();

  if (data == null) return null;

  return AppProfile(
    id: data['id'] as String,
    fullName: (data['full_name'] as String?) ?? '',
    role: (data['role'] as String?) ?? 'viewer',
  );
});
