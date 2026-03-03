import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../domain/uniform_line.dart';
import '../domain/uniform_order_row.dart';
import 'uniforms_share_stub.dart'
    if (dart.library.html) 'uniforms_share_web.dart'
    if (dart.library.io) 'uniforms_share_io.dart' as share_impl;

class SizesSummaryRow {
  const SizesSummaryRow({
    required this.size,
    required this.gender,
    required this.quantity,
  });

  final String size;
  final String gender;
  final int quantity;
}

List<SizesSummaryRow> aggregateSizesSummary(List<UniformLine> lines) {
  final counts = <String, int>{};
  final labels = <String, ({String size, String gender})>{};

  for (final line in lines) {
    final size = (line.jerseySize ?? '').trim();
    final gender = (line.uniformGender ?? '').trim();
    final key = '${size.toLowerCase()}|${gender.toLowerCase()}';
    counts[key] = (counts[key] ?? 0) + (line.isExtra ? line.qty : 1);
    labels[key] = (size: size, gender: gender);
  }

  final rows = counts.entries.map((entry) {
    final label = labels[entry.key]!;
    return SizesSummaryRow(
      size: label.size,
      gender: label.gender,
      quantity: entry.value,
    );
  }).toList()
    ..sort((a, b) {
      final bySize = a.size.toLowerCase().compareTo(b.size.toLowerCase());
      if (bySize != 0) return bySize;
      return a.gender.toLowerCase().compareTo(b.gender.toLowerCase());
    });

  return rows;
}

class UniformsExporter {
  UniformsExporter._();

  static Uint8List buildSizesWorkbook(List<UniformLine> lines) {
    final excel = Excel.createExcel();
    final defaultSheetName = excel.getDefaultSheet();
    const sheetName = 'Lista de tallas';
    final sheet = excel[sheetName];
    if (defaultSheetName != null && defaultSheetName != sheetName) {
      excel.delete(defaultSheetName);
    }

    sheet.appendRow(<CellValue>[
      TextCellValue('Talla'),
      TextCellValue('Género'),
      TextCellValue('Cantidad'),
    ]);

    final rows = aggregateSizesSummary(lines);
    for (final row in rows) {
      sheet.appendRow(<CellValue>[
        TextCellValue(row.size),
        TextCellValue(row.gender),
        IntCellValue(row.quantity),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('No se pudo generar el archivo Excel.');
    }
    return Uint8List.fromList(bytes);
  }

  static Uint8List buildOrderWorkbook(List<UniformLine> lines) {
    final excel = Excel.createExcel();
    final defaultSheetName = excel.getDefaultSheet();
    const sheetName = 'Pedido';
    final sheet = excel[sheetName];
    if (defaultSheetName != null && defaultSheetName != sheetName) {
      excel.delete(defaultSheetName);
    }

    sheet.appendRow(<CellValue>[
      TextCellValue('No.'),
      TextCellValue('Nombre'),
      TextCellValue('Número #'),
      TextCellValue('Talla'),
      TextCellValue('Género'),
    ]);

    final rows = buildUniformOrderRows(lines);
    for (final row in rows) {
      sheet.appendRow(<CellValue>[
        IntCellValue(row.number),
        TextCellValue(row.name),
        TextCellValue(row.jerseyNumber?.toString() ?? ''),
        TextCellValue(row.jerseySize ?? ''),
        TextCellValue(row.uniformGender ?? ''),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('No se pudo generar el archivo Excel.');
    }
    return Uint8List.fromList(bytes);
  }

  static Future<void> shareOrderExcel({
    required Uint8List bytes,
    required String filename,
    required String seasonName,
  }) {
    return share_impl.shareOrderExcel(
      bytes: bytes,
      filename: filename,
      seasonName: seasonName,
    );
  }
}
