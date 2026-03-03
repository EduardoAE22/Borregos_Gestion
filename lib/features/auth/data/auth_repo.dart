import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepo {
  AuthRepo(this._client);

  final SupabaseClient _client;

  Stream<User?> currentUserStream() {
    return _client.auth.onAuthStateChange.map((event) => event.session?.user);
  }

  User? get currentUser => _client.auth.currentUser;

  Future<void> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> logout() async {
    await _client.auth.signOut();
  }
}
