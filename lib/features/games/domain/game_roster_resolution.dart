import 'game.dart';

String? resolveRosterSeasonIdForCapture(
  Game game, {
  required String? activeSeasonId,
}) {
  final seasonId = game.seasonId?.trim();
  if (seasonId != null && seasonId.isNotEmpty) {
    return seasonId;
  }

  final rosterSeasonId = game.rosterSeasonId?.trim();
  if (rosterSeasonId != null && rosterSeasonId.isNotEmpty) {
    return rosterSeasonId;
  }

  final active = activeSeasonId?.trim();
  if (active == null || active.isEmpty) return null;
  return active;
}
