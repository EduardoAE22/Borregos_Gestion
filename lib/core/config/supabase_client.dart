import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';

class MissingSupabaseConfigException implements Exception {
  const MissingSupabaseConfigException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AppSupabase {
  AppSupabase._();

  static Future<void> initialize() async {
    final url = Env.supabaseUrl.trim();
    final anonKey = Env.supabaseAnonKey.trim();
    if (kDebugMode) {
      debugPrint(
        '[Config] SUPABASE_URL received=${url.isEmpty ? 'null/empty' : url}',
      );
      debugPrint(
        '[Config] SUPABASE_ANON_KEY length=${anonKey.isEmpty ? 0 : anonKey.length}',
      );
    }

    if (url.isEmpty || anonKey.isEmpty) {
      final message = [
        'Configuracion de Supabase faltante.',
        'Define SUPABASE_URL y SUPABASE_ANON_KEY con --dart-define.',
      ].join(' ');
      if (kDebugMode) {
        debugPrint('[Config] $message');
        debugPrint(
          '[Config] SUPABASE_URL empty=${url.isEmpty}, SUPABASE_ANON_KEY empty=${anonKey.isEmpty}',
        );
      }
      throw MissingSupabaseConfigException(message);
    }

    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }
}
