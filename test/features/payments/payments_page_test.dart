import 'package:borregos_gestion/features/auth/providers/auth_providers.dart';
import 'package:borregos_gestion/features/payments/domain/payment.dart';
import 'package:borregos_gestion/features/payments/domain/uniform_campaign.dart';
import 'package:borregos_gestion/features/payments/domain/weekly_payments_board.dart';
import 'package:borregos_gestion/features/payments/payments_page.dart';
import 'package:borregos_gestion/features/payments/providers/payments_providers.dart';
import 'package:borregos_gestion/features/payments/providers/uniform_campaigns_providers.dart';
import 'package:borregos_gestion/features/players/domain/player.dart';
import 'package:borregos_gestion/features/seasons/domain/season.dart';
import 'package:borregos_gestion/features/seasons/providers/seasons_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('swipe delete pide confirmacion', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const player = Player(
      id: 'p1',
      seasonId: 'season-1',
      jerseyNumber: 7,
      firstName: 'Eduardo',
      lastName: 'Acosta',
      jerseyName: 'Lalo',
    );
    final payment = PaymentRow(
      id: 'pay-1',
      seasonId: 'season-1',
      playerId: 'p1',
      conceptId: 'concept-1',
      amount: 200,
      paidAmount: 200,
      status: 'paid',
      paidAt: DateTime(2026, 3, 10),
      weekStart: DateTime(2026, 3, 9),
      weekEnd: DateTime(2026, 3, 15),
      conceptName: 'Semana',
    );

    final dashboard = WeeklyPaymentsDashboardData(
      players: [
        WeeklyPlayerPaymentCardData(
          player: player,
          weekStatus: WeeklyPaymentStatus(
            state: WeeklyPaymentState.paid,
            paymentState: PaymentState.paid,
            amountExpected: 200,
            amountPaid: 200,
            currentPayment: payment,
            paidAt: payment.paidAt,
          ),
          debtCount: 0,
        ),
      ],
      totalActivePlayers: 1,
      paidPlayers: 1,
      partialPlayers: 0,
      pendingPlayers: 0,
      totalDebts: 0,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith(
            (ref) async => const AppProfile(
              id: 'u1',
              fullName: 'Coach',
              role: 'coach',
            ),
          ),
          activeSeasonProvider.overrideWith(
            (ref) async => Season(
              id: 'season-1',
              name: '2026',
              startsOn: DateTime(2026, 2, 1),
              endsOn: DateTime(2026, 12, 1),
              isActive: true,
            ),
          ),
          activeSeasonActivePlayersProvider.overrideWith(
            (ref) async => [player],
          ),
          weeklyPaymentsDashboardProvider.overrideWith(
            (ref, weekStart) async => dashboard,
          ),
          uniformCampaignsByActiveSeasonProvider.overrideWith(
            (ref) async => const <UniformCampaign>[],
          ),
          paymentsByCategoryProvider.overrideWith(
            (ref, category) async => const <PaymentRow>[],
          ),
          uniformPaymentConceptProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(home: PaymentsPage()),
      ),
    );

    await tester.pumpAndSettle();

    final dismissible = find.byType(Dismissible).first;
    await tester.drag(dismissible, const Offset(-800, 0));
    await tester.pumpAndSettle();

    expect(find.text('Eliminar pago'), findsOneWidget);
    expect(find.textContaining('¿Eliminar pago de'), findsOneWidget);
  });

  testWidgets('filtro Abono aparece y filtra tarjetas parciales',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const p1 = Player(
      id: 'p1',
      seasonId: 'season-1',
      jerseyNumber: 1,
      firstName: 'Ana',
      lastName: 'Uno',
      jerseyName: 'A',
    );
    const p2 = Player(
      id: 'p2',
      seasonId: 'season-1',
      jerseyNumber: 2,
      firstName: 'Beto',
      lastName: 'Dos',
      jerseyName: 'B',
    );
    const p3 = Player(
      id: 'p3',
      seasonId: 'season-1',
      jerseyNumber: 3,
      firstName: 'Caro',
      lastName: 'Tres',
      jerseyName: 'C',
    );

    final dashboard = WeeklyPaymentsDashboardData(
      players: [
        WeeklyPlayerPaymentCardData(
          player: p1,
          weekStatus: const WeeklyPaymentStatus(
            state: WeeklyPaymentState.unpaid,
            paymentState: PaymentState.pending,
            amountExpected: 130,
            amountPaid: 0,
          ),
          debtCount: 1,
        ),
        WeeklyPlayerPaymentCardData(
          player: p2,
          weekStatus: const WeeklyPaymentStatus(
            state: WeeklyPaymentState.partial,
            paymentState: PaymentState.partial,
            amountExpected: 130,
            amountPaid: 50,
          ),
          debtCount: 0,
        ),
        WeeklyPlayerPaymentCardData(
          player: p3,
          weekStatus: const WeeklyPaymentStatus(
            state: WeeklyPaymentState.paid,
            paymentState: PaymentState.paid,
            amountExpected: 130,
            amountPaid: 130,
          ),
          debtCount: 0,
        ),
      ],
      totalActivePlayers: 3,
      paidPlayers: 1,
      partialPlayers: 1,
      pendingPlayers: 1,
      totalDebts: 1,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith(
            (ref) async => const AppProfile(
              id: 'u1',
              fullName: 'Coach',
              role: 'coach',
            ),
          ),
          activeSeasonProvider.overrideWith(
            (ref) async => Season(
              id: 'season-1',
              name: '2026',
              startsOn: DateTime(2026, 2, 1),
              endsOn: DateTime(2026, 12, 1),
              isActive: true,
            ),
          ),
          activeSeasonActivePlayersProvider
              .overrideWith((ref) async => [p1, p2, p3]),
          weeklyPaymentsDashboardProvider.overrideWith(
            (ref, weekStart) async => dashboard,
          ),
          uniformCampaignsByActiveSeasonProvider.overrideWith(
            (ref) async => const <UniformCampaign>[],
          ),
          paymentsByCategoryProvider.overrideWith(
            (ref, category) async => const <PaymentRow>[],
          ),
          uniformPaymentConceptProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(home: PaymentsPage()),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Abono'), findsOneWidget);

    await tester.tap(find.text('Abono'));
    await tester.pumpAndSettle();

    expect(find.textContaining('#2'), findsOneWidget);
    expect(find.textContaining('#1'), findsNothing);
    expect(find.textContaining('#3'), findsNothing);
  });
}
