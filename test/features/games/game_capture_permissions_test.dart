import 'package:borregos_gestion/features/auth/providers/auth_providers.dart';
import 'package:borregos_gestion/features/games/domain/game.dart';
import 'package:borregos_gestion/features/games/game_capture_page.dart';
import 'package:borregos_gestion/features/games/providers/games_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('GameCapturePage bloquea visualizacion de jugadas para viewer',
      (tester) async {
    final game = Game(
      id: 'g1',
      seasonId: 's1',
      rosterSeasonId: null,
      opponent: 'Rival',
      gameDate: DateTime(2026, 2, 24),
      gameType: 'torneo',
      isTournament: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith(
            (ref) async => const AppProfile(
              id: 'viewer-1',
              fullName: 'Viewer',
              role: 'viewer',
            ),
          ),
          gameByIdProvider.overrideWith((ref, id) async => game),
        ],
        child: const MaterialApp(home: GameCapturePage(gameId: 'g1')),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('No tienes permisos para ver jugadas'), findsOneWidget);
  });
}
