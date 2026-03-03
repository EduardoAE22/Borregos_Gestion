import 'package:borregos_gestion/features/payments/domain/payment.dart';
import 'package:borregos_gestion/features/payments/domain/uniform_campaign.dart';
import 'package:borregos_gestion/features/players/domain/player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calculateUniformCampaignDeposit calcula anticipo esperado', () {
    expect(
      calculateUniformCampaignDeposit(unitPrice: 550, depositPercent: 50),
      275,
    );
  });

  test('buildUniformCampaignPlayerSummaries calcula estados por jugador', () {
    const campaign = UniformCampaign(
      id: 'campaign-1',
      seasonId: 'season-1',
      name: 'Uniforme Marzo 2026',
      unitPrice: 550,
      depositPercent: 50,
    );
    const players = [
      Player(
        id: 'p1',
        seasonId: 'season-1',
        jerseyNumber: 1,
        firstName: 'Ana',
        lastName: 'Uno',
      ),
      Player(
        id: 'p2',
        seasonId: 'season-1',
        jerseyNumber: 2,
        firstName: 'Beto',
        lastName: 'Dos',
      ),
      Player(
        id: 'p3',
        seasonId: 'season-1',
        jerseyNumber: 3,
        firstName: 'Carla',
        lastName: 'Tres',
      ),
    ];

    final summaries = buildUniformCampaignPlayerSummaries(
      players: players,
      campaign: campaign,
      payments: [
        PaymentRow(
          id: 'pay-1',
          seasonId: 'season-1',
          playerId: 'p2',
          conceptId: 'concept-1',
          amount: 200,
          paidAmount: 200,
          status: 'partial',
          paidAt: DateTime(2026, 3, 10),
          uniformCampaignId: 'campaign-1',
          conceptName: 'Uniforme',
        ),
        PaymentRow(
          id: 'pay-2',
          seasonId: 'season-1',
          playerId: 'p3',
          conceptId: 'concept-1',
          amount: 550,
          paidAmount: 550,
          status: 'paid',
          paidAt: DateTime(2026, 3, 11),
          uniformCampaignId: 'campaign-1',
          conceptName: 'Uniforme',
        ),
      ],
    );

    expect(summaries[0].state, UniformCampaignPaymentState.unpaid);
    expect(summaries[1].state, UniformCampaignPaymentState.partial);
    expect(summaries[2].state, UniformCampaignPaymentState.complete);
    expect(summaries[1].remaining, 350);
  });

  test('buildUniformCampaignPlayerSummaries no mezcla pagos entre campanas',
      () {
    const campaign = UniformCampaign(
      id: 'campaign-a',
      seasonId: 'season-1',
      name: 'Uniforme A',
      unitPrice: 550,
      depositPercent: 50,
    );
    const players = [
      Player(
        id: 'p1',
        seasonId: 'season-1',
        jerseyNumber: 1,
        firstName: 'Ana',
        lastName: 'Uno',
      ),
    ];

    final summaries = buildUniformCampaignPlayerSummaries(
      players: players,
      campaign: campaign,
      payments: [
        PaymentRow(
          id: 'pay-a',
          seasonId: 'season-1',
          playerId: 'p1',
          conceptId: 'concept-1',
          amount: 100,
          paidAmount: 100,
          status: 'partial',
          paidAt: DateTime(2026, 3, 10),
          uniformCampaignId: 'campaign-a',
          conceptName: 'Uniforme',
        ),
        PaymentRow(
          id: 'pay-b',
          seasonId: 'season-1',
          playerId: 'p1',
          conceptId: 'concept-1',
          amount: 450,
          paidAmount: 450,
          status: 'paid',
          paidAt: DateTime(2026, 3, 11),
          uniformCampaignId: 'campaign-b',
          conceptName: 'Uniforme',
        ),
      ],
    );

    expect(summaries.single.totalPaid, 100);
    expect(summaries.single.state, UniformCampaignPaymentState.partial);
  });
}
