import 'package:borregos_gestion/features/players/combine_rankings_page.dart';
import 'package:borregos_gestion/features/players/domain/combine.dart';
import 'package:borregos_gestion/features/players/providers/combine_providers.dart';
import 'package:borregos_gestion/features/seasons/domain/season.dart';
import 'package:borregos_gestion/features/seasons/providers/seasons_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('toggle de modo cambia entre Por prueba e Índice atlético',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeSeasonProvider.overrideWith(
            (ref) async => Season(
              id: 'season-1',
              name: 'Temporada 2026',
              startsOn: DateTime(2026, 1, 1),
              endsOn: DateTime(2026, 12, 1),
              isActive: true,
            ),
          ),
          combineSessionsByActiveSeasonProvider.overrideWith(
            (ref) async => [
              CombineSession(
                id: 'session-1',
                seasonId: 'season-1',
                nombre: 'Combine Marzo',
                fecha: DateTime(2026, 3, 9),
              ),
            ],
          ),
          combineTestsProvider.overrideWith(
            (ref) async => const [
              CombineTest(
                id: 'test-1',
                codigo: 'dash_40',
                nombre: '40 yardas',
                unidad: 's',
                mejor: 'menor',
                esActiva: true,
              ),
            ],
          ),
          combineRankingsProvider.overrideWith(
            (ref, args) async => const [
              CombineRankingRow(
                playerId: 'p1',
                jerseyNumber: 12,
                nombre: 'Jugador A',
                valor: 4.8,
                unidad: 's',
                testCode: 'dash_40',
              ),
            ],
          ),
          combineAthleticIndexProvider.overrideWith(
            (ref, sessionId) async => const [
              CombineAthleticRankRow(
                playerId: 'p1',
                jerseyNumber: 12,
                nombre: 'Jugador A',
                athleticIndex: 78.4,
                capturedCount: 5,
                totalTests: 7,
              ),
            ],
          ),
        ],
        child: const MaterialApp(
          home: CombineRankingsPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Prueba'), findsWidgets);

    await tester.tap(find.text('Índice atlético'));
    await tester.pumpAndSettle();

    expect(find.text('Pruebas: 5/7'), findsOneWidget);
    expect(find.text('78.4'), findsOneWidget);
  });
}
