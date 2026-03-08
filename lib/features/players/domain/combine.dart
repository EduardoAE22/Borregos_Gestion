import 'player.dart';

typedef UUID = String;

class CombineSession {
  const CombineSession({
    required this.id,
    required this.seasonId,
    required this.nombre,
    required this.fecha,
    this.notas,
    this.createdAt,
  });

  final UUID id;
  final UUID seasonId;
  final String nombre;
  final DateTime fecha;
  final String? notas;
  final DateTime? createdAt;

  factory CombineSession.fromMap(Map<String, dynamic> map) {
    final parsedDate = DateTime.parse(map['fecha'] as String);
    return CombineSession(
      id: map['id'] as UUID,
      seasonId: map['season_id'] as UUID,
      nombre: (map['nombre'] as String? ?? '').trim(),
      fecha: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
      notas: (map['notas'] as String?)?.trim(),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'season_id': seasonId,
      'nombre': nombre.trim(),
      'fecha': DateTime(fecha.year, fecha.month, fecha.day)
          .toIso8601String()
          .split('T')
          .first,
      'notas': (notas ?? '').trim().isEmpty ? null : notas!.trim(),
    };
  }
}

class CombineTest {
  const CombineTest({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.unidad,
    required this.mejor,
    required this.esActiva,
  });

  final UUID id;
  final String codigo;
  final String nombre;
  final String unidad;
  final String mejor;
  final bool esActiva;

  bool get mejorEsMenor => mejor.trim().toLowerCase() == 'menor';

  factory CombineTest.fromMap(Map<String, dynamic> map) {
    return CombineTest(
      id: map['id'] as UUID,
      codigo: (map['codigo'] as String? ?? '').trim(),
      nombre: (map['nombre'] as String? ?? '').trim(),
      unidad: (map['unidad'] as String? ?? '').trim(),
      mejor: (map['mejor'] as String? ?? '').trim(),
      esActiva: map['es_activa'] as bool? ?? true,
    );
  }
}

class CombineResult {
  const CombineResult({
    required this.id,
    required this.sessionId,
    required this.playerId,
    required this.testId,
    required this.valor,
    required this.intento,
    this.extras,
    this.createdAt,
  });

  final UUID id;
  final UUID sessionId;
  final UUID playerId;
  final UUID testId;
  final double valor;
  final int intento;
  final Map<String, dynamic>? extras;
  final DateTime? createdAt;

  double? get split10 => parseSplitValue(extras?['t10']);
  double? get split20 => parseSplitValue(extras?['t20']);

  factory CombineResult.fromMap(Map<String, dynamic> map) {
    return CombineResult(
      id: map['id'] as UUID,
      sessionId: map['session_id'] as UUID,
      playerId: map['player_id'] as UUID,
      testId: map['test_id'] as UUID,
      valor: _parseNumeric(map['valor']),
      intento: (map['intento'] as num?)?.toInt() ?? 1,
      extras: map['extras'] is Map<String, dynamic>
          ? map['extras'] as Map<String, dynamic>
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'test_id': testId,
      'valor': valor,
      'extras': extras,
      'intento': intento,
    };
  }

  static double _parseNumeric(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw) ?? 0;
    return 0;
  }
}

class CombineResultInput {
  const CombineResultInput({
    required this.testId,
    required this.valor,
    this.extras,
    this.intento = 1,
  });

  final UUID testId;
  final double valor;
  final Map<String, dynamic>? extras;
  final int intento;

  Map<String, dynamic> toMap() {
    return {
      'test_id': testId,
      'valor': valor,
      'extras': extras,
      'intento': intento,
    };
  }
}

class CombineRankingRow {
  const CombineRankingRow({
    required this.playerId,
    required this.jerseyNumber,
    required this.nombre,
    required this.valor,
    required this.unidad,
    this.testId,
    this.jerseyName,
    this.testCode,
    this.testNombre,
  });

  final UUID playerId;
  final int? jerseyNumber;
  final String nombre;
  final double valor;
  final String unidad;
  final UUID? testId;
  final String? jerseyName;
  final String? testCode;
  final String? testNombre;

  String get nombreMostrado {
    final alias = (jerseyName ?? '').trim();
    if (alias.isNotEmpty) return alias;
    return nombre;
  }
}

class CombineAthleticRankRow {
  const CombineAthleticRankRow({
    required this.playerId,
    required this.jerseyNumber,
    required this.nombre,
    required this.athleticIndex,
    required this.capturedCount,
    required this.totalTests,
    this.jerseyName,
  });

  final UUID playerId;
  final int? jerseyNumber;
  final String nombre;
  final double athleticIndex;
  final int capturedCount;
  final int totalTests;
  final String? jerseyName;

  String get nombreMostrado {
    final alias = (jerseyName ?? '').trim();
    if (alias.isNotEmpty) return alias;
    return nombre;
  }
}

class CombineBalancedTeamsResult {
  const CombineBalancedTeamsResult({
    required this.teamA,
    required this.teamB,
  });

  final List<CombineAthleticRankRow> teamA;
  final List<CombineAthleticRankRow> teamB;

  double get teamATotal =>
      teamA.fold(0, (total, row) => total + row.athleticIndex);
  double get teamBTotal =>
      teamB.fold(0, (total, row) => total + row.athleticIndex);
  double get difference => (teamATotal - teamBTotal).abs();
}

Map<String, dynamic>? buildCombineExtras({
  double? split10,
  double? split20,
}) {
  final data = <String, dynamic>{};
  if (split10 != null) data['t10'] = split10;
  if (split20 != null) data['t20'] = split20;
  return data.isEmpty ? null : data;
}

double? parseSplitValue(dynamic raw) {
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw);
  return null;
}

List<CombineRankingRow> sortCombineRankings({
  required List<CombineRankingRow> rows,
  required CombineTest test,
}) {
  final sorted = [...rows];
  sorted.sort((a, b) {
    final valueCompare = test.mejorEsMenor
        ? a.valor.compareTo(b.valor)
        : b.valor.compareTo(a.valor);
    if (valueCompare != 0) return valueCompare;
    final jerseyA = a.jerseyNumber ?? 999999;
    final jerseyB = b.jerseyNumber ?? 999999;
    final jerseyCompare = jerseyA.compareTo(jerseyB);
    if (jerseyCompare != 0) return jerseyCompare;
    return a.nombreMostrado
        .toLowerCase()
        .compareTo(b.nombreMostrado.toLowerCase());
  });
  return sorted;
}

bool combinePlayerMatchesSearch(Player player, String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return true;

  final haystack = <String>[
    (player.jerseyName ?? '').trim(),
    player.firstName,
    player.lastName,
    player.jerseyNumber.toString(),
  ].map((value) => value.toLowerCase());

  return haystack.any((value) => value.contains(normalized));
}

bool isCombineLowerBetter({String? mejor, String? codigo}) {
  final normalizedMejor = (mejor ?? '').trim().toLowerCase();
  if (normalizedMejor == 'menor') return true;
  if (normalizedMejor == 'mayor') return false;

  final normalizedCode = (codigo ?? '').trim().toLowerCase();
  const lowerBetterCodes = <String>{
    'dash_40',
    'tres_conos',
    'shuttle_20',
    'shuttle_60',
    'lanzadera_20',
    'lanzadera_60',
  };
  return lowerBetterCodes.contains(normalizedCode);
}

List<CombineAthleticRankRow> calculateCombineAthleticIndexRows({
  required List<CombineRankingRow> rows,
}) {
  if (rows.isEmpty) return const <CombineAthleticRankRow>[];

  final rowsByTest = <String, List<CombineRankingRow>>{};
  for (final row in rows) {
    final key = row.testId ?? row.testCode ?? '';
    if (key.isEmpty) continue;
    rowsByTest.putIfAbsent(key, () => <CombineRankingRow>[]).add(row);
  }
  if (rowsByTest.isEmpty) return const <CombineAthleticRankRow>[];

  final totalTests = rowsByTest.length;
  final scoreByPlayer = <String, List<double>>{};
  final playerMeta = <String, CombineRankingRow>{};

  for (final testRows in rowsByTest.values) {
    if (testRows.isEmpty) continue;
    final lowerBetter = isCombineLowerBetter(
      codigo: testRows.first.testCode,
    );
    final min = testRows
        .map((row) => row.valor)
        .reduce((current, next) => current < next ? current : next);
    final max = testRows
        .map((row) => row.valor)
        .reduce((current, next) => current > next ? current : next);

    for (final row in testRows) {
      final score = min == max
          ? 100.0
          : lowerBetter
              ? ((max - row.valor) / (max - min)) * 100
              : ((row.valor - min) / (max - min)) * 100;
      scoreByPlayer.putIfAbsent(row.playerId, () => <double>[]).add(score);
      playerMeta[row.playerId] = row;
    }
  }

  final ranking = scoreByPlayer.entries.map((entry) {
    final meta = playerMeta[entry.key]!;
    final scores = entry.value;
    final avg = scores.reduce((a, b) => a + b) / scores.length;
    return CombineAthleticRankRow(
      playerId: entry.key,
      jerseyNumber: meta.jerseyNumber,
      nombre: meta.nombre,
      jerseyName: meta.jerseyName,
      athleticIndex: avg,
      capturedCount: scores.length,
      totalTests: totalTests,
    );
  }).toList();

  ranking.sort((a, b) {
    final indexCompare = b.athleticIndex.compareTo(a.athleticIndex);
    if (indexCompare != 0) return indexCompare;
    final jerseyA = a.jerseyNumber ?? 999999;
    final jerseyB = b.jerseyNumber ?? 999999;
    final jerseyCompare = jerseyA.compareTo(jerseyB);
    if (jerseyCompare != 0) return jerseyCompare;
    return a.nombreMostrado
        .toLowerCase()
        .compareTo(b.nombreMostrado.toLowerCase());
  });

  return ranking;
}

CombineBalancedTeamsResult buildBalancedTeamsSnake({
  required List<CombineAthleticRankRow> players,
  int seed = 0,
}) {
  if (players.isEmpty) {
    return const CombineBalancedTeamsResult(teamA: [], teamB: []);
  }

  final shuffled = [...players];
  shuffled.sort((a, b) {
    final compare = b.athleticIndex.compareTo(a.athleticIndex);
    if (compare != 0) return compare;
    final jerseyA = a.jerseyNumber ?? 999999;
    final jerseyB = b.jerseyNumber ?? 999999;
    final jerseyCompare = jerseyA.compareTo(jerseyB);
    if (jerseyCompare != 0) return jerseyCompare;
    return a.nombreMostrado
        .toLowerCase()
        .compareTo(b.nombreMostrado.toLowerCase());
  });
  if (seed != 0) {
    _shuffleEqualScoreGroups(shuffled, _SeededRandom(seed));
  }

  final teamA = <CombineAthleticRankRow>[];
  final teamB = <CombineAthleticRankRow>[];

  for (var i = 0; i < shuffled.length; i++) {
    final row = shuffled[i];
    final pairIndex = i ~/ 2;
    final assignToA = pairIndex.isEven ? i.isEven : i.isOdd;
    if (assignToA) {
      teamA.add(row);
    } else {
      teamB.add(row);
    }
  }

  return CombineBalancedTeamsResult(teamA: teamA, teamB: teamB);
}

void _shuffleEqualScoreGroups(
  List<CombineAthleticRankRow> rows,
  _SeededRandom random,
) {
  var start = 0;
  while (start < rows.length) {
    var end = start + 1;
    while (end < rows.length &&
        rows[end].athleticIndex == rows[start].athleticIndex) {
      end++;
    }
    if (end - start > 1) {
      for (var i = end - 1; i > start; i--) {
        final swapIndex = start + random.nextInt(i - start + 1);
        final tmp = rows[i];
        rows[i] = rows[swapIndex];
        rows[swapIndex] = tmp;
      }
    }
    start = end;
  }
}

String buildBalancedTeamsWhatsappText(CombineBalancedTeamsResult teams) {
  final buffer = StringBuffer()
    ..writeln('Equipos balanceados (Índice atlético)')
    ..writeln('')
    ..writeln('Equipo A (${teams.teamATotal.toStringAsFixed(1)}):');
  for (final row in teams.teamA) {
    buffer.writeln(
      '- #${row.jerseyNumber ?? '-'} ${row.nombreMostrado} (${row.athleticIndex.toStringAsFixed(1)})',
    );
  }
  buffer
    ..writeln('')
    ..writeln('Equipo B (${teams.teamBTotal.toStringAsFixed(1)}):');
  for (final row in teams.teamB) {
    buffer.writeln(
      '- #${row.jerseyNumber ?? '-'} ${row.nombreMostrado} (${row.athleticIndex.toStringAsFixed(1)})',
    );
  }
  buffer
    ..writeln('')
    ..writeln('Diferencia: ${teams.difference.toStringAsFixed(1)}');

  return buffer.toString();
}

class _SeededRandom {
  _SeededRandom(int seed) : _state = seed;

  int _state;

  int nextInt(int max) {
    if (max <= 0) return 0;
    _state = (_state * 1103515245 + 12345) & 0x7fffffff;
    return _state % max;
  }
}
