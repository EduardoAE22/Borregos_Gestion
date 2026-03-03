import 'package:borregos_gestion/features/dashboard/dashboard_payments_summary.dart';
import 'package:borregos_gestion/features/payments/domain/payment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ignora pagos con paid_amount 0 en resumen de dashboard', () {
    final summary = buildDashboardPaymentsSummary(
      now: DateTime(2026, 3, 20),
      payments: [
        PaymentRow(
          id: 'pay-1',
          seasonId: 'season-1',
          playerId: 'player-1',
          conceptId: 'concept-1',
          amount: 500,
          paidAmount: 0,
          status: 'paid',
          paidAt: DateTime(2026, 3, 5),
        ),
        PaymentRow(
          id: 'pay-2',
          seasonId: 'season-1',
          playerId: 'player-2',
          conceptId: 'concept-1',
          amount: 500,
          paidAmount: 250,
          status: 'partial',
          paidAt: DateTime(2026, 3, 10),
        ),
        PaymentRow(
          id: 'pay-3',
          seasonId: 'season-1',
          playerId: 'player-3',
          conceptId: 'concept-1',
          amount: 500,
          paidAmount: 100,
          status: 'pending',
          paidAt: DateTime(2026, 3, 11),
        ),
        PaymentRow(
          id: 'pay-4',
          seasonId: 'season-1',
          playerId: 'player-4',
          conceptId: 'concept-1',
          amount: 500,
          paidAmount: 300,
          status: 'paid',
          paidAt: DateTime(2026, 2, 28),
        ),
      ],
    );

    expect(summary.totalPaidMonth, 250);
    expect(summary.registeredPaymentsCount, 1);
  });
}
