import 'package:borregos_gestion/features/uniforms/data/uniforms_exporter.dart';
import 'package:borregos_gestion/features/uniforms/domain/uniform_line.dart';
import 'package:borregos_gestion/features/uniforms/domain/uniform_order_row.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('aggregateSizesSummary agrupa por talla y genero sumando cantidad', () {
    final lines = <UniformLine>[
      const UniformLine(
        qty: 1,
        name: 'Jugador 1',
        jerseySize: 'M',
        uniformGender: 'H',
        type: 'Jugador',
        isExtra: false,
      ),
      const UniformLine(
        qty: 1,
        name: 'Jugador 2',
        jerseySize: 'M',
        uniformGender: 'H',
        type: 'Jugador',
        isExtra: false,
      ),
      const UniformLine(
        qty: 3,
        name: 'Extra Porra',
        jerseySize: 'M',
        uniformGender: 'H',
        type: 'Porra',
        isExtra: true,
      ),
      const UniformLine(
        qty: 2,
        name: 'Extra Familiar',
        jerseySize: 'S',
        uniformGender: 'M',
        type: 'Familiar',
        isExtra: true,
      ),
    ];

    final summary = aggregateSizesSummary(lines);
    final byKey = <String, int>{
      for (final row in summary) '${row.size}|${row.gender}': row.quantity,
    };

    expect(byKey['M|H'], 5);
    expect(byKey['S|M'], 2);
  });

  test('buildUniformOrderRows expande extras y No. es consecutivo', () {
    final lines = <UniformLine>[
      const UniformLine(
        qty: 1,
        name: 'Jugador 12',
        jerseyNumber: 12,
        jerseySize: 'M',
        uniformGender: 'H',
        type: 'Jugador',
        isExtra: false,
      ),
      const UniformLine(
        qty: 3,
        name: 'Porra Azul',
        jerseySize: 'S',
        uniformGender: 'M',
        type: 'Porra',
        isExtra: true,
      ),
    ];

    final rows = buildUniformOrderRows(lines);

    expect(rows, hasLength(4));
    expect(rows[0].number, 1);
    expect(rows[0].name, 'Jugador 12');
    expect(rows[0].jerseyNumber, 12);
    expect(rows[1].number, 2);
    expect(rows[2].number, 3);
    expect(rows[3].number, 4);
    expect(rows[1].name, 'Porra Azul');
    expect(rows[2].name, 'Porra Azul');
    expect(rows[3].name, 'Porra Azul');
    expect(rows[1].jerseyNumber, isNull);
  });

  test('buildOrderWorkbook genera una sola hoja Pedido con jugadores y extras',
      () {
    final lines = <UniformLine>[
      const UniformLine(
        qty: 1,
        name: 'Jugador 12',
        jerseyNumber: 12,
        jerseySize: 'M',
        uniformGender: 'H',
        type: 'Jugador',
        isExtra: false,
      ),
      const UniformLine(
        qty: 2,
        name: 'Porra Azul',
        jerseySize: 'S',
        uniformGender: 'M',
        type: 'Porra',
        isExtra: true,
      ),
    ];

    final bytes = UniformsExporter.buildOrderWorkbook(lines);
    final workbook = Excel.decodeBytes(bytes);

    expect(workbook.tables.keys, ['Pedido']);
    final sheet = workbook.tables['Pedido'];
    expect(sheet, isNotNull);
    expect(sheet!.rows.length, 4);
    expect(sheet.rows[0].map((cell) => cell?.value?.toString()).toList(), [
      'No.',
      'Nombre',
      'Número #',
      'Talla',
      'Género',
    ]);
    expect(sheet.rows[1].map((cell) => cell?.value?.toString()).toList(), [
      '1',
      'Jugador 12',
      '12',
      'M',
      'H',
    ]);
    expect(sheet.rows[2].map((cell) => cell?.value?.toString()).toList(), [
      '2',
      'Porra Azul',
      '',
      'S',
      'M',
    ]);
    expect(sheet.rows[3].map((cell) => cell?.value?.toString()).toList(), [
      '3',
      'Porra Azul',
      '',
      'S',
      'M',
    ]);
  });

  test('1 jugador + 1 extra quantity 3 produce 4 filas consecutivas', () {
    final lines = <UniformLine>[
      const UniformLine(
        qty: 1,
        name: 'Jugador 7',
        jerseyNumber: 7,
        jerseySize: 'L',
        uniformGender: 'H',
        type: 'Jugador',
        isExtra: false,
      ),
      const UniformLine(
        qty: 3,
        name: 'Extra Staff',
        jerseySize: 'M',
        uniformGender: 'M',
        type: 'Extra',
        isExtra: true,
      ),
    ];

    final rows = buildUniformOrderRows(lines);
    final bytes = UniformsExporter.buildOrderWorkbook(lines);
    final workbook = Excel.decodeBytes(bytes);

    expect(rows.map((row) => row.number).toList(), [1, 2, 3, 4]);
    expect(rows, hasLength(4));
    expect(workbook.tables.keys, ['Pedido']);
  });
}
