import 'package:borregos_gestion/features/auth/ui/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Login precarga el last_email guardado', (tester) async {
    SharedPreferences.setMockInitialValues({
      'last_email': 'coach@borregos.com',
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final emailField = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Email'),
    );
    final emailController = emailField.controller;

    expect(emailController, isNotNull);
    expect(emailController!.text, 'coach@borregos.com');
  });
}
