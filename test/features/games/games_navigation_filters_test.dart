import 'package:borregos_gestion/features/auth/providers/auth_providers.dart';
import 'package:borregos_gestion/features/games/domain/game.dart';
import 'package:borregos_gestion/features/games/games_page.dart';
import 'package:borregos_gestion/features/games/providers/games_providers.dart';
import 'package:borregos_gestion/features/seasons/domain/season.dart';
import 'package:borregos_gestion/features/seasons/providers/seasons_providers.dart';
import 'package:borregos_gestion/features/seasons/season_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('/partidos filtra por tipo amistoso/interno', (tester) async {
    final friendly = Game(
      id: 'g1',
      seasonId: null,
      opponent: 'Tigres',
      gameDate: DateTime(2026, 2, 10),
      gameType: 'amistoso',
    );
    final internal = Game(
      id: 'g2',
      seasonId: null,
      opponent: 'Interno A vs Interno B',
      gameDate: DateTime(2026, 2, 11),
      gameType: 'interno',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith(
            (ref) async =>
                const AppProfile(id: 'u1', fullName: 'Coach', role: 'coach'),
          ),
          globalGamesByTypeProvider.overrideWith((ref, type) async {
            if (type == 'interno') return [internal];
            return [friendly];
          }),
        ],
        child: const MaterialApp(home: GamesPage()),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.textContaining('Tigres'), findsOneWidget);
    expect(find.textContaining('Interno A vs Interno B'), findsNothing);

    await tester.tap(find.text('Internos'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Interno A vs Interno B'), findsOneWidget);
    expect(find.textContaining('Tigres'), findsNothing);
  });

  testWidgets('detalle de temporada solo muestra partidos de torneo',
      (tester) async {
    final season = Season(
      id: 's1',
      name: 'Nacional 2026',
      startsOn: DateTime(2026, 1, 1),
      endsOn: DateTime(2026, 12, 31),
      isActive: true,
    );
    final tournament = Game(
      id: 'g3',
      seasonId: 's1',
      opponent: 'Halcones',
      gameDate: DateTime(2026, 3, 1),
      gameType: 'torneo',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith(
            (ref) async =>
                const AppProfile(id: 'u2', fullName: 'Viewer', role: 'viewer'),
          ),
          seasonsListProvider.overrideWith((ref) async => [season]),
          tournamentGamesBySeasonProvider
              .overrideWith((ref, _) async => [tournament]),
        ],
        child: const MaterialApp(home: SeasonDetailPage(seasonId: 's1')),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.textContaining('Halcones'), findsOneWidget);
    expect(find.text('Estadísticas'), findsNothing);
    expect(find.text('Amistosos'), findsNothing);
    expect(find.text('Internos'), findsNothing);
  });
}
