import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/logger.dart';
import '../domain/player.dart';
import '../domain/player_metric.dart';

class PlayerPhotoUploadValidationException implements Exception {
  const PlayerPhotoUploadValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PlayerPhotoFormatException implements Exception {
  const PlayerPhotoFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PlayersRepo {
  PlayersRepo(this._client);

  final SupabaseClient _client;
  static const _bucket = 'player_photos';

  Future<List<Player>> listPlayers(String seasonId) async {
    final stopwatch = Stopwatch()..start();
    final data = await _client
        .from('players')
        .select()
        .eq('season_id', seasonId)
        .order('jersey_number', ascending: true);
    stopwatch.stop();
    AppLogger.perf('PlayersRepo.listPlayers',
        elapsed: stopwatch.elapsed, detail: 'season=$seasonId');

    return (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Player.fromMap)
        .toList();
  }

  Future<Player?> getPlayer(String id) async {
    final stopwatch = Stopwatch()..start();
    final data =
        await _client.from('players').select().eq('id', id).maybeSingle();
    stopwatch.stop();
    AppLogger.perf('PlayersRepo.getPlayer',
        elapsed: stopwatch.elapsed, detail: 'id=$id');
    if (data == null) return null;
    return Player.fromMap(data);
  }

  Future<Player> upsertPlayer(Player player) async {
    if (player.id == null) {
      final created = await _client
          .from('players')
          .insert(player.toMap())
          .select()
          .single();
      return Player.fromMap(created);
    }

    final updated = await _client
        .from('players')
        .update(player.toMap())
        .eq('id', player.id!)
        .select()
        .single();

    return Player.fromMap(updated);
  }

  Future<void> setPlayerActive(String id, bool isActive) async {
    await _client.from('players').update({'is_active': isActive}).eq('id', id);
  }

  Future<void> setPlayerWantsUniform(String id, bool value) async {
    await _client.from('players').update({'wants_uniform': value}).eq('id', id);
  }

  Future<void> deletePlayer(String playerId) async {
    await _client.from('players').delete().eq('id', playerId);
  }

  Future<({String photoPath, String? photoThumbPath})> uploadPlayerPhoto({
    required String seasonId,
    required String playerId,
    required String filename,
    required Uint8List bytes,
    String? oldPhotoPath,
    String? oldPhotoThumbPath,
  }) async {
    AppLogger.info(
      'PlayersRepo.uploadPlayerPhoto',
      'Inicio upload playerId=$playerId seasonId=$seasonId filename=$filename bytes=${bytes.length}',
    );
    final stopwatch = Stopwatch()..start();
    final detected = _detectImageFormat(filename: filename, bytes: bytes);
    AppLogger.info(
      'PlayersRepo.uploadPlayerPhoto',
      'detectedFormat=${detected.detectedFormat} extFinal=${detected.ext} contentType=${detected.contentType}',
    );
    final ts = DateTime.now().millisecondsSinceEpoch;
    final objectPath = 'season_$seasonId/player_$playerId/$ts.${detected.ext}';
    final thumbObjectPath = 'season_$seasonId/player_$playerId/${ts}_thumb.jpg';
    AppLogger.info(
      'PlayersRepo.uploadPlayerPhoto',
      'Bytes originales=${bytes.length}',
    );

    await _client.storage.from(_bucket).uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: detected.contentType,
          ),
        );
    AppLogger.info(
      'PlayersRepo.uploadPlayerPhoto',
      'Upload storage OK path=$objectPath bucket=$_bucket',
    );

    String? newPhotoThumbPath;
    try {
      final thumbBytes = _buildJpegThumbnail(bytes);
      if (thumbBytes != null) {
        AppLogger.info(
          'PlayersRepo.uploadPlayerPhoto',
          'Bytes thumb=${thumbBytes.length}',
        );
        await _client.storage.from(_bucket).uploadBinary(
              thumbObjectPath,
              thumbBytes,
              fileOptions: const FileOptions(
                upsert: true,
                contentType: 'image/jpeg',
              ),
            );
        newPhotoThumbPath = thumbObjectPath;
        AppLogger.info(
          'PlayersRepo.uploadPlayerPhoto',
          'Upload thumb OK path=$thumbObjectPath',
        );
      } else {
        AppLogger.info(
          'PlayersRepo.uploadPlayerPhoto',
          'No se pudo generar thumbnail, se conserva solo foto full.',
        );
      }
    } catch (e) {
      AppLogger.info(
        'PlayersRepo.uploadPlayerPhoto',
        'Fallo generando/subiendo thumb; continua con foto full. error=$e',
      );
      newPhotoThumbPath = null;
    }

    try {
      final signedProbe =
          await _client.storage.from(_bucket).createSignedUrl(objectPath, 60);
      AppLogger.info(
        'PlayersRepo.uploadPlayerPhoto',
        'Validacion storage OK path=$objectPath probe=$signedProbe',
      );
    } catch (e) {
      AppLogger.info(
        'PlayersRepo.uploadPlayerPhoto',
        'Validacion storage fallo path=$objectPath error=$e',
      );
      throw const PlayerPhotoUploadValidationException(
        'Upload fallo: objeto no existe en storage.',
      );
    }

    final newPhotoPath = objectPath;

    if (oldPhotoPath != null && oldPhotoPath.isNotEmpty) {
      final oldPath = _normalizeStoragePath(oldPhotoPath);
      if (oldPath != null && oldPath.isNotEmpty) {
        try {
          await _client.storage.from(_bucket).remove([oldPath]);
        } catch (e) {
          AppLogger.info('PlayersRepo.uploadPlayerPhoto',
              'No se pudo borrar foto previa: $e');
        }
      }
    }
    if (oldPhotoThumbPath != null && oldPhotoThumbPath.isNotEmpty) {
      final oldThumbPath = _normalizeStoragePath(oldPhotoThumbPath);
      if (oldThumbPath != null && oldThumbPath.isNotEmpty) {
        try {
          await _client.storage.from(_bucket).remove([oldThumbPath]);
        } catch (e) {
          AppLogger.info('PlayersRepo.uploadPlayerPhoto',
              'No se pudo borrar thumb previa: $e');
        }
      }
    }

    final legacyPhotoUrl = newPhotoPath;
    final legacyPhotoThumbUrl = newPhotoThumbPath;
    AppLogger.info(
      'PlayersRepo.uploadPlayerPhoto',
      'Updating player $playerId: photo_url=$legacyPhotoUrl, photo_thumb_url=$legacyPhotoThumbUrl',
    );

    await _client.from('players').update({
      'photo_path': newPhotoPath,
      'photo_thumb_path': newPhotoThumbPath,
      // Compatibilidad temporal para flujo legacy.
      'photo_url': legacyPhotoUrl,
      'photo_thumb_url': legacyPhotoThumbUrl,
    }).eq('id', playerId);
    AppLogger.info(
      'PlayersRepo.uploadPlayerPhoto',
      'DB update photo_path OK playerId=$playerId photoPath=$newPhotoPath',
    );
    stopwatch.stop();
    AppLogger.perf(
      'PlayersRepo.uploadPlayerPhoto',
      elapsed: stopwatch.elapsed,
      detail: 'playerId=$playerId path=$objectPath',
    );
    return (photoPath: newPhotoPath, photoThumbPath: newPhotoThumbPath);
  }

  ({String detectedFormat, String ext, String contentType}) _detectImageFormat({
    required String filename,
    required Uint8List bytes,
  }) {
    final lowerFilename = filename.toLowerCase().trim();
    if (lowerFilename.endsWith('.heic') || lowerFilename.endsWith('.heif')) {
      throw const PlayerPhotoFormatException(
        'Formato HEIC/HEIF no soportado. Usa JPG, PNG o WEBP.',
      );
    }

    // JPEG: FF D8 FF
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return (
        detectedFormat: 'jpeg',
        ext: 'jpg',
        contentType: 'image/jpeg',
      );
    }

    // PNG: 89 50 4E 47
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return (
        detectedFormat: 'png',
        ext: 'png',
        contentType: 'image/png',
      );
    }

    // WebP: "RIFF....WEBP"
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return (
        detectedFormat: 'webp',
        ext: 'webp',
        contentType: 'image/webp',
      );
    }

    // HEIC/HEIF: ISO BMFF header containing ftyp + brand heic/heif/heix/hevc.
    if (bytes.length >= 12 &&
        bytes[4] == 0x66 &&
        bytes[5] == 0x74 &&
        bytes[6] == 0x79 &&
        bytes[7] == 0x70) {
      final brand = String.fromCharCodes(bytes.sublist(8, 12)).toLowerCase();
      if (brand == 'heic' ||
          brand == 'heif' ||
          brand == 'heix' ||
          brand == 'hevc') {
        throw const PlayerPhotoFormatException(
          'Formato HEIC/HEIF no soportado. Usa JPG, PNG o WEBP.',
        );
      }
    }

    throw const PlayerPhotoFormatException(
      'Formato de imagen no valido. Usa JPG, PNG o WEBP.',
    );
  }

  String? _normalizeStoragePath(String rawValue) {
    final cleaned = rawValue.split('?').first.trim();
    if (cleaned.isEmpty) return null;
    if (!cleaned.startsWith('http://') && !cleaned.startsWith('https://')) {
      return cleaned;
    }

    final uri = Uri.tryParse(cleaned);
    if (uri == null) return null;

    final segments = uri.pathSegments;
    final bucketIndex = segments.indexOf(_bucket);
    if (bucketIndex == -1 || bucketIndex + 1 >= segments.length) return null;

    return segments.sublist(bucketIndex + 1).join('/');
  }

  Uint8List? _buildJpegThumbnail(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final resized =
        decoded.width > 256 ? img.copyResize(decoded, width: 256) : decoded;
    var quality = 70;
    Uint8List out =
        Uint8List.fromList(img.encodeJpg(resized, quality: quality));
    const targetBytes = 80 * 1024;

    while (out.length > targetBytes && quality > 45) {
      quality -= 5;
      out = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
    }
    AppLogger.info(
      'PlayersRepo.uploadPlayerPhoto',
      'Thumb quality final=$quality bytes=${out.length} target=$targetBytes',
    );
    return out;
  }

  Future<void> auditPlayerPhotoUrlsSample({int limit = 5}) async {
    final data = await _client
        .from('players')
        .select('id,photo_path,photo_thumb_path')
        .not('photo_path', 'is', null)
        .limit(limit);
    final rows = (data as List<dynamic>).cast<Map<String, dynamic>>();
    for (final row in rows) {
      final photoPath = (row['photo_path'] as String?)?.trim() ?? '';
      final thumbPath = (row['photo_thumb_path'] as String?)?.trim() ?? '';
      final ext = _extractUrlExtension(photoPath);
      final hasBust = photoPath.contains(RegExp(r'([?&])v='));
      final rareExt =
          ext != 'jpg' && ext != 'jpeg' && ext != 'png' && ext != 'webp';
      AppLogger.info(
        'PlayersRepo.auditPlayerPhotoUrlsSample',
        'playerId=${row['id']} ext=$ext hasBust=$hasBust rareExt=$rareExt photoPath=$photoPath thumbPath=$thumbPath',
      );
    }
  }

  String _extractUrlExtension(String url) {
    final cleaned = url.split('?').first;
    final dot = cleaned.lastIndexOf('.');
    if (dot == -1 || dot + 1 >= cleaned.length) return '';
    return cleaned.substring(dot + 1).toLowerCase();
  }

  Future<PlayerMetric> addMetric(String playerId, PlayerMetric metric) async {
    final created = await _client
        .from('player_metrics')
        .insert(metric.copyWith(playerId: playerId).toMap())
        .select()
        .single();

    return PlayerMetric.fromMap(created);
  }

  Future<List<PlayerMetric>> listMetrics(String playerId) async {
    final data = await _client
        .from('player_metrics')
        .select()
        .eq('player_id', playerId)
        .order('measured_on', ascending: false);

    return (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(PlayerMetric.fromMap)
        .toList();
  }
}
