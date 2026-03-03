import 'package:borregos_gestion/features/auth/providers/auth_providers.dart';
import 'package:borregos_gestion/features/players/domain/player.dart';
import 'package:borregos_gestion/features/players/players_list_page.dart';
import 'package:borregos_gestion/features/players/providers/players_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'PlayersListPage muestra empty state cuando no hay temporada activa',
      (tester) async {
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
            (ref) async => (season: null, players: const <Player>[]),
          ),
        ],
        child: const MaterialApp(home: PlayersListPage()),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Sin temporada activa'), findsOneWidget);
  });
}
