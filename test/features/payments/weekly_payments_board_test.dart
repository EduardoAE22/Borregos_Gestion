import 'package:borregos_gestion/features/payments/domain/payment.dart';
import 'package:borregos_gestion/features/payments/domain/weekly_payments_board.dart';
import 'package:borregos_gestion/features/players/domain/player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('getWeekStartMonday regresa el lunes mas reciente', () {
    expect(
      getWeekStartMonday(DateTime(2026, 2, 27)),
      DateTime(2026, 2, 23),
    );
    expect(
      getWeekStartMonday(DateTime(2026, 2, 23)),
      DateTime(2026, 2, 23),
    );
  });

  test('calcula adeudos por jugador usando pagos de rango sin N queries', () {
    final players = <Player>[
      const Player(
        id: 'p1',
        seasonId: 'season-1',
        jerseyNumber: 1,
        firstName: 'Ana',
        lastName: 'Uno',
      ),
      const Player(
        id: 'p2',
        seasonId: 'season-1',
        jerseyNumber: 2,
        firstName: 'Beto',
        lastName: 'Dos',
      ),
    ];

    final payments = <PaymentRow>[
      PaymentRow(
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
      ),
      PaymentRow(
        id: 'pay-2',
        seasonId: 'season-1',
        playerId: 'p1',
        conceptId: 'concept-1',
        amount: 200,
        paidAmount: 100,
        status: 'partial',
        paidAt: DateTime(2026, 3, 17),
        weekStart: DateTime(2026, 3, 16),
        weekEnd: DateTime(2026, 3, 22),
      ),
      PaymentRow(
        id: 'pay-3',
        seasonId: 'season-1',
        playerId: 'p2',
        conceptId: 'concept-1',
        amount: 200,
        paidAmount: 200,
        status: 'paid',
        paidAt: DateTime(2026, 3, 24),
        weekStart: DateTime(2026, 3, 23),
        weekEnd: DateTime(2026, 3, 29),
      ),
    ];

    final debts = calculatePlayerDebtCounts(
      players: players,
      paymentsInRange: payments,
      seasonStart: DateTime(2026, 2, 2),
      selectedWeekStart: DateTime(2026, 3, 30),
    );

    expect(debts['p1'], 2);
    expect(debts['p2'], 3);
  });

  test('adeudos son 0 antes del 09-03-2026 para todos', () {
    final players = <Player>[
      const Player(
        id: 'p1',
        seasonId: 'season-1',
        jerseyNumber: 12,
        firstName: 'Ana',
        lastName: 'Rios',
      ),
    ];

    final debts = calculatePlayerDebtCounts(
      players: players,
      paymentsInRange: const <PaymentRow>[],
      seasonStart: DateTime(2026, 2, 2),
      selectedWeekStart: DateTime(2026, 3, 2),
    );

    expect(debts['p1'], 0);
  });

  test('playerMatchesSearch hace match por jerseyName apellido y numero', () {
    const player = Player(
      id: 'p1',
      seasonId: 'season-1',
      jerseyNumber: 88,
      firstName: 'Eduardo',
      lastName: 'Acosta',
      jerseyName: 'Lalo',
    );

    expect(playerMatchesSearch(player, 'lalo'), isTrue);
    expect(playerMatchesSearch(player, 'acosta'), isTrue);
    expect(playerMatchesSearch(player, '88'), isTrue);
    expect(playerMatchesSearch(player, 'zzz'), isFalse);
  });
}
