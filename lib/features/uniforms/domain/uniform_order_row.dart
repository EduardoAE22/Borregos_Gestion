import 'uniform_line.dart';

class UniformOrderRow {
  const UniformOrderRow({
    required this.number,
    required this.name,
    this.jerseyNumber,
    this.jerseySize,
    this.uniformGender,
  });

  final int number;
  final String name;
  final int? jerseyNumber;
  final String? jerseySize;
  final String? uniformGender;
}

List<UniformOrderRow> buildUniformOrderRows(List<UniformLine> lines) {
  final rows = <UniformOrderRow>[];

  for (final line in lines) {
    final copies = line.isExtra ? (line.qty <= 0 ? 1 : line.qty) : 1;
    for (var i = 0; i < copies; i++) {
      rows.add(
        UniformOrderRow(
          number: rows.length + 1,
          name: line.name,
          jerseyNumber: line.jerseyNumber,
          jerseySize: line.jerseySize,
          uniformGender: line.uniformGender,
        ),
      );
    }
  }

  return rows;
}
