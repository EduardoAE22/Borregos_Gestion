import 'package:borregos_gestion/features/players/domain/combine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildCombineExtras regresa null si no hay splits', () {
    expect(buildCombineExtras(split10: null, split20: null), isNull);
  });

  test('buildCombineExtras mapea t10 y t20 cuando vienen capturados', () {
    final extras = buildCombineExtras(split10: 1.7, split20: 2.9);
    expect(extras, isNotNull);
    expect(extras!['t10'], 1.7);
    expect(extras['t20'], 2.9);
  });

  test('CombineResult parsea splits opcionales desde extras', () {
    final result = CombineResult.fromMap({
      'id': 'r1',
      'session_id': 's1',
      'player_id': 'p1',
      'test_id': 't1',
      'valor': 4.8,
      'extras': {'t10': 1.7},
      'intento': 1,
      'created_at': DateTime(2026, 3, 5).toIso8601String(),
    });

    expect(result.split10, 1.7);
    expect(result.split20, isNull);
  });
}
