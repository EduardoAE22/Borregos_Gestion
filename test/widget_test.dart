import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:borregos_gestion/app.dart';
import 'package:borregos_gestion/core/config/router.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('BorregosApp smoke test renders without Supabase',
      (WidgetTester tester) async {
    final testRouter = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('Smoke'))),
        ),
      ],
    );

    addTearDown(testRouter.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(testRouter),
        ],
        child: const BorregosApp(),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Smoke'), findsOneWidget);
  });
}
