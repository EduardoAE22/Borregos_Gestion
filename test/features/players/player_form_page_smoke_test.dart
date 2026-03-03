import 'package:borregos_gestion/features/auth/providers/auth_providers.dart';
import 'package:borregos_gestion/features/players/player_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('PlayerFormPage bloquea edicion para viewer', (tester) async {
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
        ],
        child: const MaterialApp(home: PlayerFormPage()),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Tu rol no tiene permisos para editar jugadores.'),
        findsOneWidget);
  });
}
