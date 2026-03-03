import '../payments/domain/payment.dart';

class DashboardPaymentsSummary {
  const DashboardPaymentsSummary({
    required this.totalPaidMonth,
    required this.registeredPaymentsCount,
  });

  final double totalPaidMonth;
  final int registeredPaymentsCount;
}

DashboardPaymentsSummary buildDashboardPaymentsSummary({
  required List<PaymentRow> payments,
  required DateTime now,
}) {
  final monthPayments = payments.where((payment) {
    final isCurrentMonth =
        payment.paidAt.year == now.year && payment.paidAt.month == now.month;
    final hasPositivePaidAmount = payment.paidAmount > 0;
    final isPaidLike = payment.status == 'paid' || payment.status == 'partial';
    return isCurrentMonth && hasPositivePaidAmount && isPaidLike;
  }).toList();

  final totalPaidMonth = monthPayments.fold<double>(
    0,
    (sum, payment) => sum + payment.paidAmount,
  );

  return DashboardPaymentsSummary(
    totalPaidMonth: totalPaidMonth,
    registeredPaymentsCount: monthPayments.length,
  );
}
