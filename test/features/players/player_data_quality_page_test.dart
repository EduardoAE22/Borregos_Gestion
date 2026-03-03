import 'package:borregos_gestion/features/players/domain/player.dart';
import 'package:borregos_gestion/features/players/player_data_quality_page.dart';
import 'package:borregos_gestion/features/players/providers/players_providers.dart';
import 'package:borregos_gestion/features/seasons/domain/season.dart';
import 'package:borregos_gestion/features/seasons/providers/seasons_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Player _player({
  required String id,
  required int jersey,
  required String firstName,
  required String lastName,
  String? position = 'WR',
  String? photoUrl = 'https://example.com/photo.jpg',
}) {
  return Player(
    id: id,
    seasonId: 'season-1',
    jerseyNumber: jersey,
    firstName: firstName,
    lastName: lastName,
    position: position,
    phone: '9991234567',
    emergencyContact: 'Contacto',
    photoUrl: photoUrl,
    heightCm: 175,
    weightKg: 78,
    isActive: true,
  );
}

void main() {
  testWidgets('DataQuality aplica filtro por chip Foto y permite quitarlo',
      (tester) async {
    final season = Season(
      id: 'season-1',
      name: '2026',
      startsOn: DateTime(2026, 1, 1),
      endsOn: DateTime(2026, 12, 31),
      isActive: true,
    );

    final players = <Player>[
      _player(
        id: 'p1',
        jersey: 10,
        firstName: 'Sin',
        lastName: 'Foto',
        photoUrl: null,
      ),
      _player(
        id: 'p2',
        jersey: 11,
        firstName: 'Sin',
        lastName: 'Posicion',
        position: null,
      ),
      _player(
        id: 'p3',
        jersey: 12,
        firstName: 'Completo',
        lastName: 'Ok',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeSeasonProvider.overrideWith((ref) async => season),
          playersByActiveSeasonProvider.overrideWith((ref) async => players),
        ],
        child: const MaterialApp(
          home: PlayerDataQualityPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('#10 Sin Foto'), findsOneWidget);
    expect(find.textContaining('#11 Sin Posicion'), findsOneWidget);
    expect(find.textContaining('Filtro: Todos'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Foto (1)'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Filtro: Foto'), findsOneWidget);
    expect(find.textContaining('#10 Sin Foto'), findsOneWidget);
    expect(find.textContaining('#11 Sin Posicion'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Foto (1)'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Filtro: Todos'), findsOneWidget);
    expect(find.textContaining('#10 Sin Foto'), findsOneWidget);
    expect(find.textContaining('#11 Sin Posicion'), findsOneWidget);
  });
}
