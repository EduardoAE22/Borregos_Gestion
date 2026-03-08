import 'package:borregos_gestion/features/auth/providers/auth_providers.dart';
import 'package:borregos_gestion/features/players/domain/player.dart';
import 'package:borregos_gestion/features/players/players_list_page.dart';
import 'package:borregos_gestion/features/players/providers/players_providers.dart';
import 'package:borregos_gestion/features/seasons/domain/season.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('PlayersList navega a /combine-rankings desde el boton',
      (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/players',
          builder: (context, state) => const PlayersListPage(),
        ),
        GoRoute(
          path: '/combine-rankings',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Rankings Combine'))),
        ),
      ],
      initialLocation: '/players',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith(
            (ref) async => const AppProfile(
              id: 'coach-1',
              fullName: 'Coach',
              role: 'coach',
            ),
          ),
          activeSeasonPlayersBundleProvider.overrideWith(
            (ref) async => (
              season: Season(
                id: 'season-1',
                name: '2026',
                startsOn: DateTime(2026, 2, 1),
                endsOn: DateTime(2026, 12, 1),
                isActive: true,
              ),
              players: const <Player>[],
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rankings Combine').last);
    await tester.pumpAndSettle();
    expect(find.text('Rankings Combine'), findsOneWidget);
  });
}
