import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlayerPhotoSignedUrlService {
  PlayerPhotoSignedUrlService(this._client);

  final SupabaseClient _client;
  static const String _bucket = 'player_photos';
  final Map<String, _CacheEntry> _cache = <String, _CacheEntry>{};
  final Map<String, Future<String>> _pending = <String, Future<String>>{};

  Future<String?> getSignedUrl(
    String? path, {
    Duration expiresIn = const Duration(days: 1),
  }) async {
    final normalized = _normalizePath(path);
    if (normalized == null) return null;
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return normalized;
    }

    final now = DateTime.now();
    final cached = _cache[normalized];
    if (cached != null && now.isBefore(cached.validUntil)) {
      return cached.url;
    }

    final pending = _pending[normalized];
    if (pending != null) return pending;

    final future = _client.storage
        .from(_bucket)
        .createSignedUrl(normalized, expiresIn.inSeconds);
    _pending[normalized] = future;

    try {
      final url = await future;
      final safeMargin = expiresIn > const Duration(minutes: 2)
          ? const Duration(minutes: 1)
          : Duration.zero;
      _cache[normalized] = _CacheEntry(
        url: url,
        validUntil: now.add(expiresIn - safeMargin),
      );
      return url;
    } finally {
      _pending.remove(normalized);
    }
  }

  void evict(String? path) {
    final normalized = _normalizePath(path);
    if (normalized == null) return;
    _cache.remove(normalized);
    _pending.remove(normalized);
  }

  String? _normalizePath(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return raw.split('?').first;
  }
}

class _CacheEntry {
  const _CacheEntry({
    required this.url,
    required this.validUntil,
  });

  final String url;
  final DateTime validUntil;
}

final playerPhotoSignedUrlServiceProvider =
    Provider<PlayerPhotoSignedUrlService>((ref) {
  return PlayerPhotoSignedUrlService(Supabase.instance.client);
});

final playerPhotoSignedUrlProvider =
    FutureProvider.family<String?, String?>((ref, path) async {
  return ref.read(playerPhotoSignedUrlServiceProvider).getSignedUrl(path);
});
