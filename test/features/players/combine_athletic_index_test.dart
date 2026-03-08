import 'package:borregos_gestion/features/players/domain/combine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Índice atlético invierte escala cuando menor es mejor', () {
    final rows = <CombineRankingRow>[
      const CombineRankingRow(
        playerId: 'p1',
        jerseyNumber: 12,
        nombre: 'Jugador A',
        valor: 4.8,
        unidad: 's',
        testId: 't1',
        testCode: 'dash_40',
      ),
      const CombineRankingRow(
        playerId: 'p2',
        jerseyNumber: 7,
        nombre: 'Jugador B',
        valor: 5.2,
        unidad: 's',
        testId: 't1',
        testCode: 'dash_40',
      ),
    ];

    final ranking = calculateCombineAthleticIndexRows(rows: rows);
    expect(ranking.first.playerId, 'p1');
    expect(ranking.first.athleticIndex, 100);
    expect(ranking.last.athleticIndex, 0);
  });

  test('Índice atlético asigna 100 cuando min == max', () {
    final rows = <CombineRankingRow>[
      const CombineRankingRow(
        playerId: 'p1',
        jerseyNumber: 1,
        nombre: 'Jugador A',
        valor: 10,
        unidad: 'reps',
        testId: 't1',
        testCode: 'bench',
      ),
      const CombineRankingRow(
        playerId: 'p2',
        jerseyNumber: 2,
        nombre: 'Jugador B',
        valor: 10,
        unidad: 'reps',
        testId: 't1',
        testCode: 'bench',
      ),
    ];

    final ranking = calculateCombineAthleticIndexRows(rows: rows);
    expect(ranking.length, 2);
    expect(ranking[0].athleticIndex, 100);
    expect(ranking[1].athleticIndex, 100);
  });

  test('Índice promedia solo pruebas capturadas y conserva X/Y', () {
    final rows = <CombineRankingRow>[
      const CombineRankingRow(
        playerId: 'p1',
        jerseyNumber: 12,
        nombre: 'Jugador A',
        valor: 10,
        unidad: 'reps',
        testId: 'bench-id',
        testCode: 'bench',
      ),
      const CombineRankingRow(
        playerId: 'p2',
        jerseyNumber: 7,
        nombre: 'Jugador B',
        valor: 20,
        unidad: 'reps',
        testId: 'bench-id',
        testCode: 'bench',
      ),
      const CombineRankingRow(
        playerId: 'p1',
        jerseyNumber: 12,
        nombre: 'Jugador A',
        valor: 4.9,
        unidad: 's',
        testId: 'dash-id',
        testCode: 'dash_40',
      ),
    ];

    final ranking = calculateCombineAthleticIndexRows(rows: rows);
    final playerA = ranking.firstWhere((row) => row.playerId == 'p1');
    final playerB = ranking.firstWhere((row) => row.playerId == 'p2');

    expect(playerA.capturedCount, 2);
    expect(playerA.totalTests, 2);
    expect(playerA.athleticIndex, 50);

    expect(playerB.capturedCount, 1);
    expect(playerB.totalTests, 2);
    expect(playerB.athleticIndex, 100);
  });
}
