import 'package:borregos_gestion/features/payments/domain/payment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('isWeeklyPaymentConceptName detecta Semana y Semanal sin importar case',
      () {
    expect(isWeeklyPaymentConceptName('Semana'), isTrue);
    expect(isWeeklyPaymentConceptName('Semanal'), isTrue);
    expect(isWeeklyPaymentConceptName('  semanal  '), isTrue);
    expect(isWeeklyPaymentConceptName('SEMANA'), isTrue);
    expect(isWeeklyPaymentConceptName('Uniforme'), isFalse);
    expect(isWeeklyPaymentConceptName(null), isFalse);
  });
}
