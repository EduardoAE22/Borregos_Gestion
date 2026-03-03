import 'package:borregos_gestion/features/uniforms/domain/uniform_extra.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UniformExtra.fromMap usa 1 cuando quantity es null', () {
    final extra = UniformExtra.fromMap({
      'id': 'extra-1',
      'season_id': 'season-1',
      'name': 'Porra',
      'quantity': null,
    });

    expect(extra.quantity, 1);
  });

  test('UniformExtra.fromMap acepta qty legacy como quantity', () {
    final extra = UniformExtra.fromMap({
      'id': 'extra-2',
      'season_id': 'season-1',
      'name': 'Staff',
      'qty': 4,
    });

    expect(extra.quantity, 4);
  });

  test('UniformExtra.toMap no persiste relation y usa quantity', () {
    const extra = UniformExtra(
      id: 'extra-3',
      seasonId: 'season-1',
      name: 'Porra',
      quantity: 2,
    );

    final map = extra.toMap();

    expect(map['quantity'], 2);
    expect(map.containsKey('relation'), isFalse);
  });
}
