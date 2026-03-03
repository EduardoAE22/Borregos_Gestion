import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppLogger {
  AppLogger._();

  static void supabaseError(
    PostgrestException error, {
    required String scope,
  }) {
    debugPrint('[Supabase][$scope] message: ${error.message}');
    debugPrint('[Supabase][$scope] details: ${error.details ?? '-'}');
    debugPrint('[Supabase][$scope] code: ${error.code ?? '-'}');
    debugPrint('[Supabase][$scope] hint: ${error.hint ?? '-'}');
  }

  static void info(String scope, String message) {
    debugPrint('[Info][$scope] $message');
  }

  static void perf(
    String scope, {
    required Duration elapsed,
    String? detail,
  }) {
    final suffix = detail == null || detail.trim().isEmpty ? '' : ' ($detail)';
    debugPrint('[Perf][$scope] ${elapsed.inMilliseconds}ms$suffix');
  }
}
