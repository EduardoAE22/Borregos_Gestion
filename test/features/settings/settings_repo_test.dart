import 'package:borregos_gestion/features/settings/data/settings_repo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseWeeklyFeeAmount convierte app_settings a double con fallback 0',
      () {
    expect(parseWeeklyFeeAmount('250'), 250);
    expect(parseWeeklyFeeAmount('199.50'), 199.5);
    expect(parseWeeklyFeeAmount('199,50'), 199.5);
    expect(parseWeeklyFeeAmount(''), 0);
    expect(parseWeeklyFeeAmount('abc'), 0);
    expect(parseWeeklyFeeAmount(null), 0);
  });
}
