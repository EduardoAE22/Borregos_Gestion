import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../../core/utils/formatters.dart';
import '../domain/uniform_campaign.dart';
import '../domain/weekly_payments_board.dart';

enum PaymentsExportScope {
  training,
  uniform,
  both,
}

enum PaymentsExportSheetMode {
  singleSheet,
  twoSheets,
}

class PaymentsExporter {
  PaymentsExporter._();

  static Uint8List buildWorkbook({
    required PaymentsExportScope scope,
    required PaymentsExportSheetMode sheetMode,
    required DateTime weekStart,
    required DateTime weekEnd,
    required List<WeeklyPlayerPaymentCardData> trainingRows,
    UniformCampaign? uniformCampaign,
    List<UniformCampaignPlayerSummary> uniformRows = const [],
  }) {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();

    final includeTraining = scope == PaymentsExportScope.training ||
        scope == PaymentsExportScope.both;
    final includeUniform = scope == PaymentsExportScope.uniform ||
        scope == PaymentsExportScope.both;

    if (sheetMode == PaymentsExportSheetMode.twoSheets) {
      if (includeTraining) {
        _appendTrainingTable(
          excel['Entrenamiento'],
          weekStart: weekStart,
          weekEnd: weekEnd,
          rows: trainingRows,
        );
      }
      if (includeUniform) {
        _appendUniformTable(
          excel['Uniforme'],
          campaign: uniformCampaign,
          rows: uniformRows,
        );
      }
    } else {
      final sheet = excel['Pagos'];
      if (includeTraining) {
        sheet.appendRow(<CellValue>[
          TextCellValue(
            'ENTRENAMIENTO (${AppFormatters.date(weekStart)} - ${AppFormatters.date(weekEnd)})',
          ),
        ]);
        _appendTrainingTable(
          sheet,
          weekStart: weekStart,
          weekEnd: weekEnd,
          rows: trainingRows,
          includeTitle: false,
        );
      }

      if (includeUniform) {
        if (includeTraining) {
          sheet.appendRow(<CellValue>[TextCellValue('')]);
        }
        final campaignName = uniformCampaign?.name ?? 'Sin campaña';
        sheet.appendRow(<CellValue>[
          TextCellValue('UNIFORME ($campaignName)'),
        ]);
        _appendUniformTable(
          sheet,
          campaign: uniformCampaign,
          rows: uniformRows,
          includeTitle: false,
        );
      }
    }

    if (defaultSheet != null &&
        defaultSheet != 'Pagos' &&
        defaultSheet != 'Entrenamiento' &&
        defaultSheet != 'Uniforme') {
      excel.delete(defaultSheet);
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('No se pudo generar el archivo Excel.');
    }
    return Uint8List.fromList(bytes);
  }

  static void _appendTrainingTable(
    Sheet sheet, {
    required DateTime weekStart,
    required DateTime weekEnd,
    required List<WeeklyPlayerPaymentCardData> rows,
    bool includeTitle = true,
  }) {
    if (includeTitle) {
      sheet.appendRow(<CellValue>[
        TextCellValue(
          'Entrenamiento ${AppFormatters.date(weekStart)} - ${AppFormatters.date(weekEnd)}',
        ),
      ]);
    }
    sheet.appendRow(_headerTraining);

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final status = row.weekStatus;
      final name = (row.player.jerseyName ?? '').trim().isNotEmpty
          ? row.player.jerseyName!.trim()
          : '${row.player.firstName} ${row.player.lastName}'.trim();
      final lastPaidAt =
          status.paidAt != null ? AppFormatters.date(status.paidAt!) : '';
      sheet.appendRow(<CellValue>[
        IntCellValue(i + 1),
        TextCellValue(_jerseyLabel(row.player.jerseyNumber)),
        TextCellValue(name),
        TextCellValue(_stateLabel(status.paymentState)),
        DoubleCellValue(status.amountPaid),
        DoubleCellValue((status.amountExpected - status.amountPaid)
            .clamp(0, status.amountExpected > 0 ? status.amountExpected : 0)),
        TextCellValue(
          '${AppFormatters.date(weekStart)} - ${AppFormatters.date(weekEnd)}',
        ),
        TextCellValue(lastPaidAt),
      ]);
    }
  }

  static void _appendUniformTable(
    Sheet sheet, {
    UniformCampaign? campaign,
    required List<UniformCampaignPlayerSummary> rows,
    bool includeTitle = true,
  }) {
    if (includeTitle) {
      sheet.appendRow(<CellValue>[
        TextCellValue('Uniforme ${campaign?.name ?? ''}'),
      ]);
    }
    sheet.appendRow(_headerUniform);

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final name = (row.player.jerseyName ?? '').trim().isNotEmpty
          ? row.player.jerseyName!.trim()
          : '${row.player.firstName} ${row.player.lastName}'.trim();
      final latest = row.latestPayment;
      final lastPaidAt =
          latest != null ? AppFormatters.date(latest.paidAt) : '';

      sheet.appendRow(<CellValue>[
        IntCellValue(i + 1),
        TextCellValue(_jerseyLabel(row.player.jerseyNumber)),
        TextCellValue(name),
        TextCellValue(_stateLabel(switch (row.state) {
          UniformCampaignPaymentState.unpaid => PaymentState.pending,
          UniformCampaignPaymentState.partial => PaymentState.partial,
          UniformCampaignPaymentState.complete => PaymentState.paid,
        })),
        DoubleCellValue(row.totalPaid),
        DoubleCellValue(row.remaining),
        TextCellValue(campaign?.name ?? ''),
        TextCellValue(lastPaidAt),
      ]);
    }
  }

  static String _stateLabel(PaymentState state) {
    return switch (state) {
      PaymentState.pending => 'PENDIENTE',
      PaymentState.partial => 'ABONO',
      PaymentState.paid => 'PAGADO',
    };
  }

  static String _jerseyLabel(int? number) => number?.toString() ?? '';

  static final List<CellValue> _headerTraining = <CellValue>[
    TextCellValue('No.'),
    TextCellValue('# Jersey'),
    TextCellValue('Nombre'),
    TextCellValue('Estado'),
    TextCellValue('Pagado'),
    TextCellValue('Falta'),
    TextCellValue('Semana (inicio-fin)'),
    TextCellValue('Último pago (fecha)'),
  ];

  static final List<CellValue> _headerUniform = <CellValue>[
    TextCellValue('No.'),
    TextCellValue('# Jersey'),
    TextCellValue('Nombre'),
    TextCellValue('Estado'),
    TextCellValue('Pagado'),
    TextCellValue('Falta'),
    TextCellValue('Campaña'),
    TextCellValue('Último pago'),
  ];
}
