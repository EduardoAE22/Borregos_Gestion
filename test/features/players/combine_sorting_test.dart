import 'package:borregos_gestion/features/players/domain/combine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sortCombineRankings ordena ascendente cuando mejor es menor', () {
    const testModel = CombineTest(
      id: 't1',
      codigo: 'dash_40',
      nombre: '40 yardas',
      unidad: 's',
      mejor: 'menor',
      esActiva: true,
    );
    final rows = <CombineRankingRow>[
      const CombineRankingRow(
        playerId: 'p1',
        jerseyNumber: 12,
        nombre: 'Jugador A',
        valor: 5.1,
        unidad: 's',
      ),
      const CombineRankingRow(
        playerId: 'p2',
        jerseyNumber: 3,
        nombre: 'Jugador B',
        valor: 4.9,
        unidad: 's',
      ),
    ];

    final sorted = sortCombineRankings(rows: rows, test: testModel);
    expect(sorted.first.playerId, 'p2');
  });

  test('sortCombineRankings ordena descendente cuando mejor es mayor', () {
    const testModel = CombineTest(
      id: 't2',
      codigo: 'bench',
      nombre: 'Press de banca',
      unidad: 'reps',
      mejor: 'mayor',
      esActiva: true,
    );
    final rows = <CombineRankingRow>[
      const CombineRankingRow(
        playerId: 'p1',
        jerseyNumber: 12,
        nombre: 'Jugador A',
        valor: 18,
        unidad: 'reps',
      ),
      const CombineRankingRow(
        playerId: 'p2',
        jerseyNumber: 3,
        nombre: 'Jugador B',
        valor: 20,
        unidad: 'reps',
      ),
    ];

    final sorted = sortCombineRankings(rows: rows, test: testModel);
    expect(sorted.first.playerId, 'p2');
  });
}
