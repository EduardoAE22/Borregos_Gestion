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
}
