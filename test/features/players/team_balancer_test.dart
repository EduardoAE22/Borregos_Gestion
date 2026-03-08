import 'package:borregos_gestion/features/players/domain/combine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildBalancedTeamsSnake asigna todos los jugadores sin duplicados', () {
    final players = List.generate(
      10,
      (index) => CombineAthleticRankRow(
        playerId: 'p$index',
        jerseyNumber: index + 1,
        nombre: 'Jugador $index',
        athleticIndex: 100 - index.toDouble(),
        capturedCount: 7,
        totalTests: 7,
      ),
    );

    final teams = buildBalancedTeamsSnake(players: players, seed: 1234);
    final assigned = [...teams.teamA, ...teams.teamB];

    expect(assigned.length, players.length);
    expect(
      assigned.map((row) => row.playerId).toSet().length,
      players.length,
    );
  });

  test('buildBalancedTeamsSnake mantiene diferencia de sumas razonable', () {
    final players = <CombineAthleticRankRow>[
      const CombineAthleticRankRow(
        playerId: 'p1',
        jerseyNumber: 1,
        nombre: 'A',
        athleticIndex: 90,
        capturedCount: 7,
        totalTests: 7,
      ),
      const CombineAthleticRankRow(
        playerId: 'p2',
        jerseyNumber: 2,
        nombre: 'B',
        athleticIndex: 88,
        capturedCount: 7,
        totalTests: 7,
      ),
      const CombineAthleticRankRow(
        playerId: 'p3',
        jerseyNumber: 3,
        nombre: 'C',
        athleticIndex: 84,
        capturedCount: 7,
        totalTests: 7,
      ),
      const CombineAthleticRankRow(
        playerId: 'p4',
        jerseyNumber: 4,
        nombre: 'D',
        athleticIndex: 82,
        capturedCount: 7,
        totalTests: 7,
      ),
      const CombineAthleticRankRow(
        playerId: 'p5',
        jerseyNumber: 5,
        nombre: 'E',
        athleticIndex: 80,
        capturedCount: 7,
        totalTests: 7,
      ),
      const CombineAthleticRankRow(
        playerId: 'p6',
        jerseyNumber: 6,
        nombre: 'F',
        athleticIndex: 78,
        capturedCount: 7,
        totalTests: 7,
      ),
    ];

    final teams = buildBalancedTeamsSnake(players: players, seed: 99);
    final maxSingle =
        players.map((row) => row.athleticIndex).reduce((a, b) => a > b ? a : b);
    expect(teams.difference <= maxSingle, isTrue);
  });
}
