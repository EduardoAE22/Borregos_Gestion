import 'package:borregos_gestion/features/payments/domain/payment.dart';
import 'package:borregos_gestion/features/payments/domain/uniform_campaign.dart';
import 'package:borregos_gestion/features/payments/providers/payments_providers.dart';
import 'package:borregos_gestion/features/payments/providers/uniform_campaigns_providers.dart';
import 'package:borregos_gestion/features/payments/ui/weekly_summary_page.dart';
import 'package:borregos_gestion/features/players/domain/player.dart';
import 'package:borregos_gestion/features/seasons/domain/season.dart';
import 'package:borregos_gestion/features/seasons/providers/seasons_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('resumen uniforme muestra contadores por campana',
      (tester) async {
    const campaign = UniformCampaign(
      id: 'camp-1',
      seasonId: 'season-1',
      name: 'Uniforme Marzo 2026',
      unitPrice: 550,
      depositPercent: 50,
    );

    const player1 = Player(
      id: 'p1',
      seasonId: 'season-1',
      jerseyNumber: 1,
      firstName: 'Ana',
      lastName: 'Uno',
    );
    const player2 = Player(
      id: 'p2',
      seasonId: 'season-1',
      jerseyNumber: 2,
      firstName: 'Beto',
      lastName: 'Dos',
    );
    const player3 = Player(
      id: 'p3',
      seasonId: 'season-1',
      jerseyNumber: 3,
      firstName: 'Caro',
      lastName: 'Tres',
    );

    final summaries = [
      const UniformCampaignPlayerSummary(
        player: player1,
        campaign: campaign,
        payments: <PaymentRow>[],
        totalPaid: 0,
      ),
      const UniformCampaignPlayerSummary(
        player: player2,
        campaign: campaign,
        payments: <PaymentRow>[],
        totalPaid: 200,
      ),
      const UniformCampaignPlayerSummary(
        player: player3,
        campaign: campaign,
        payments: <PaymentRow>[],
        totalPaid: 550,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeSeasonProvider.overrideWith(
            (ref) async => Season(
              id: 'season-1',
              name: '2026',
              startsOn: DateTime(2026, 2, 1),
              endsOn: DateTime(2026, 12, 1),
              isActive: true,
            ),
          ),
          uniformCampaignsByActiveSeasonProvider.overrideWith(
            (ref) async => const [campaign],
          ),
          uniformCampaignPlayerSummariesProvider.overrideWith(
            (ref, arg) async => summaries,
          ),
        ],
        child: const MaterialApp(
          home: WeeklySummaryPage(
            mode: PaymentsSummaryMode.uniform,
            initialCampaignId: 'camp-1',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Pago completo'), findsOneWidget);
    expect(find.text('Abonaron'), findsOneWidget);
    expect(find.text('Pendientes'), findsWidgets);
    expect(find.text('Deudores'), findsNothing);
  });
}
