import 'package:borregos_gestion/features/games/game_stats_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sortStatRowsByValue ordena de mayor a menor por valor numerico', () {
    final rows = <StatRow>[
      (label: 'Jugador A', value: 9, display: '9'),
      (label: 'Jugador B', value: 10, display: '10'),
      (label: 'Jugador C', value: 2, display: '2'),
    ];

    final sorted = sortStatRowsByValue(rows);

    expect(sorted[0].label, 'Jugador B');
    expect(sorted[1].label, 'Jugador A');
    expect(sorted[2].label, 'Jugador C');
  });
}
