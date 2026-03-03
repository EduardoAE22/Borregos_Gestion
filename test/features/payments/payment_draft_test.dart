import 'package:borregos_gestion/features/payments/domain/payment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizePaymentDraft convierte paid_amount 0 en unpaid', () {
    final draft = normalizePaymentDraft(
      amount: 500,
      paidAmount: 0,
      status: 'paid',
    );

    expect(draft.amount, 500);
    expect(draft.paidAmount, 0);
    expect(draft.status, 'unpaid');
  });

  test('normalizePaymentDraft ajusta coherencia para pago completo', () {
    final draft = normalizePaymentDraft(
      amount: 500,
      paidAmount: 500,
      status: 'pending',
    );

    expect(draft.paidAmount, 500);
    expect(draft.status, 'paid');
  });
}
