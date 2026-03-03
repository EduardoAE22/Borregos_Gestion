import '../../../core/player_profile_requirements.dart';
import 'player.dart';

class PlayerCompletenessHelper {
  PlayerCompletenessHelper._();

  static Map<String, List<String>> missingFields(List<Player> players) {
    final result = <String, List<String>>{};

    for (var i = 0; i < players.length; i++) {
      final player = players[i];
      final playerKey = player.id ?? 'index_$i';
      result[playerKey] = missingFieldKeysForPlayer(player);
    }

    return result;
  }

  static Map<String, int> commonMissingCounts(List<Player> players) {
    final counts = <String, int>{};
    for (final player in players) {
      for (final key in missingFieldKeysForPlayer(player)) {
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    return counts;
  }

  static Map<String, int> commonMissingChipCounts(List<Player> players) {
    final counts = <String, int>{};
    for (final player in players) {
      for (final key in missingChipFieldKeysForPlayer(player)) {
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    return counts;
  }

  static bool isComplete(Player player) =>
      missingFieldKeysForPlayer(player).isEmpty;

  static List<String> missingFieldKeysForPlayer(Player player) {
    final map = player.toMap();
    final missing = <String>[];

    for (final field
        in PlayerProfileRequirements.fields.where((f) => f.required)) {
      if (_isMissing(field.sourceKey, map[field.sourceKey])) {
        missing.add(field.key);
      }
    }

    return missing;
  }

  static List<String> missingChipFieldKeysForPlayer(Player player) {
    final map = player.toMap();
    final missing = <String>[];

    for (final field
        in PlayerProfileRequirements.fields.where((f) => f.qualityChip)) {
      if (_isMissing(field.sourceKey, map[field.sourceKey])) {
        missing.add(field.key);
      }
    }

    return missing;
  }

  static List<String> missingFieldLabelsForPlayer(Player player) {
    return missingFieldKeysForPlayer(player)
        .map(PlayerProfileRequirements.labelFor)
        .toList();
  }

  static List<MapEntry<String, int>> topMissing(List<Player> players,
      {int limit = 5}) {
    final entries = commonMissingCounts(players)
        .entries
        .where((entry) => entry.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).toList();
  }

  static List<MapEntry<String, int>> topMissingChipCounts(List<Player> players,
      {int? limit}) {
    final entries = commonMissingChipCounts(players)
        .entries
        .where((entry) => entry.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (limit == null) return entries;
    return entries.take(limit).toList();
  }

  static String normalizeFieldKey(String fieldKey) {
    return PlayerProfileRequirements.normalizeKey(fieldKey);
  }

  static bool _isMissing(String key, dynamic value) {
    if (value == null) return true;

    if (key == 'jersey_number' ||
        key == 'height_cm' ||
        key == 'weight_kg' ||
        key == 'age') {
      final number = value as num?;
      return number == null || number <= 0;
    }

    if (value is String) {
      return value.trim().isEmpty;
    }

    return false;
  }
}
