import 'package:borregos_gestion/features/games/domain/game.dart';
import 'package:borregos_gestion/features/games/domain/game_roster_resolution.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('partido global usa rosterSeasonId y no temporada activa', () {
    final game = Game(
      id: 'g1',
      seasonId: null,
      rosterSeasonId: 'season_roster',
      opponent: 'Rival',
      gameDate: DateTime(2026, 2, 16),
      gameType: 'amistoso',
    );

    final resolved = resolveRosterSeasonIdForCapture(
      game,
      activeSeasonId: 'season_activa',
    );

    expect(resolved, 'season_roster');
  });

  test('partido global sin roster usa temporada activa como fallback', () {
    final game = Game(
      id: 'g2',
      seasonId: null,
      rosterSeasonId: null,
      opponent: 'Rival',
      gameDate: DateTime(2026, 2, 16),
      gameType: 'interno',
    );

    final resolved = resolveRosterSeasonIdForCapture(
      game,
      activeSeasonId: 'season_activa',
    );

    expect(resolved, 'season_activa');
  });

  test('partido de torneo siempre usa seasonId del juego', () {
    final game = Game(
      id: 'g3',
      seasonId: 'season_torneo',
      rosterSeasonId: 'season_otra',
      opponent: 'Rival',
      gameDate: DateTime(2026, 2, 16),
      gameType: 'torneo',
    );

    final resolved = resolveRosterSeasonIdForCapture(
      game,
      activeSeasonId: 'season_activa',
    );

    expect(resolved, 'season_torneo');
  });
}
