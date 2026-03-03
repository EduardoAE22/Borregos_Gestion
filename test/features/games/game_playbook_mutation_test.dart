import 'package:borregos_gestion/features/games/domain/game_play.dart';
import 'package:borregos_gestion/features/games/providers/game_plays_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('crear jugada ofensiva se refleja en lista', () {
    final created = GamePlay(
      gameId: 'g1',
      half: 1,
      unit: 'ofensiva',
      down: 1,
      distanceYards: 10,
      yards: 12,
      points: 0,
      qbPlayerId: 'qb1',
      receiverPlayerId: 'wr1',
      isTarget: true,
      isCompletion: true,
      isDrop: false,
      isPassTd: false,
      isRush: false,
      isRushTd: false,
      isSack: false,
      isTackleFlag: false,
      isInterception: false,
      isPick6: false,
      isPassDefended: false,
      isPenalty: false,
    );

    final result = applyPlayMutation(
      currentPlays: const [],
      createdPlay: created,
      currentOurScore: 0,
      currentOppScore: 0,
      pointsForOur: true,
    );

    expect(result.nextPlays.length, 1);
    expect(result.nextPlays.first.unit, 'ofensiva');
  });

  test('jugada con puntos actualiza marcador según lado', () {
    final td = GamePlay(
      gameId: 'g1',
      half: 1,
      unit: 'ofensiva',
      down: 2,
      distanceYards: 5,
      yards: 20,
      points: 6,
      qbPlayerId: 'qb1',
      receiverPlayerId: 'wr1',
      isTarget: true,
      isCompletion: true,
      isDrop: false,
      isPassTd: true,
      isRush: false,
      isRushTd: false,
      isSack: false,
      isTackleFlag: false,
      isInterception: false,
      isPick6: false,
      isPassDefended: false,
      isPenalty: false,
    );

    final ours = applyPlayMutation(
      currentPlays: const [],
      createdPlay: td,
      currentOurScore: 0,
      currentOppScore: 0,
      pointsForOur: true,
    );
    expect(ours.nextOurScore, 6);
    expect(ours.nextOppScore, 0);

    final rival = applyPlayMutation(
      currentPlays: const [],
      createdPlay: td,
      currentOurScore: 6,
      currentOppScore: 7,
      pointsForOur: false,
    );
    expect(rival.nextOurScore, 6);
    expect(rival.nextOppScore, 13);
  });
}
