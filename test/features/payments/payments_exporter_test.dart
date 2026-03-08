import 'package:borregos_gestion/features/payments/data/payments_exporter.dart';
import 'package:borregos_gestion/features/payments/domain/payment.dart';
import 'package:borregos_gestion/features/payments/domain/uniform_campaign.dart';
import 'package:borregos_gestion/features/payments/domain/weekly_payments_board.dart';
import 'package:borregos_gestion/features/players/domain/player.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exporta una hoja cuando formato es singleSheet', () {
    final bytes = PaymentsExporter.buildWorkbook(
      scope: PaymentsExportScope.training,
      sheetMode: PaymentsExportSheetMode.singleSheet,
      weekStart: DateTime(2026, 3, 9),
      weekEnd: DateTime(2026, 3, 15),
      trainingRows: [
        WeeklyPlayerPaymentCardData(
          player: const Player(
            id: 'p1',
            seasonId: 'season-1',
            jerseyNumber: 12,
            firstName: 'Ana',
            lastName: 'Uno',
          ),
          weekStatus: const WeeklyPaymentStatus(
            state: WeeklyPaymentState.partial,
            paymentState: PaymentState.partial,
            amountExpected: 130,
            amountPaid: 65,
          ),
          debtCount: 1,
        ),
      ],
    );

    final workbook = Excel.decodeBytes(bytes);
    expect(workbook.tables.keys, contains('Pagos'));
    expect(workbook.tables.keys, isNot(contains('Entrenamiento')));
  });

  test('exporta dos hojas cuando formato es twoSheets y scope ambos', () {
    const campaign = UniformCampaign(
      id: 'camp-1',
      seasonId: 'season-1',
      name: 'Uniforme Marzo 2026',
      unitPrice: 550,
      depositPercent: 50,
    );

    final bytes = PaymentsExporter.buildWorkbook(
      scope: PaymentsExportScope.both,
      sheetMode: PaymentsExportSheetMode.twoSheets,
      weekStart: DateTime(2026, 3, 9),
      weekEnd: DateTime(2026, 3, 15),
      trainingRows: const <WeeklyPlayerPaymentCardData>[],
      uniformCampaign: campaign,
      uniformRows: [
        const UniformCampaignPlayerSummary(
          player: Player(
            id: 'p2',
            seasonId: 'season-1',
            jerseyNumber: 33,
            firstName: 'Beto',
            lastName: 'Dos',
          ),
          campaign: campaign,
          payments: <PaymentRow>[],
          totalPaid: 100,
        ),
      ],
    );

    final workbook = Excel.decodeBytes(bytes);
    expect(workbook.tables.keys, contains('Entrenamiento'));
    expect(workbook.tables.keys, contains('Uniforme'));
  });
}
