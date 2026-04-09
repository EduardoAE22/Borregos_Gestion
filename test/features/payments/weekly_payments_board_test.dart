import 'package:borregos_gestion/features/payments/domain/payment.dart';
import 'package:borregos_gestion/features/payments/domain/weekly_payments_board.dart';
import 'package:borregos_gestion/features/attendance/domain/attendance_entry.dart';
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

  test('calcula adeudos por jugador usando asistencia y pagos agregados', () {
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
        amount: 120,
        paidAmount: 120,
        status: 'paid',
        paidAt: DateTime(2026, 3, 31),
        weekStart: DateTime(2026, 3, 30),
        weekEnd: DateTime(2026, 4, 5),
      ),
      PaymentRow(
        id: 'pay-2',
        seasonId: 'season-1',
        playerId: 'p1',
        conceptId: 'concept-1',
        amount: 60,
        paidAmount: 30,
        status: 'partial',
        paidAt: DateTime(2026, 4, 8),
        weekStart: DateTime(2026, 4, 6),
        weekEnd: DateTime(2026, 4, 12),
      ),
      PaymentRow(
        id: 'pay-3',
        seasonId: 'season-1',
        playerId: 'p2',
        conceptId: 'concept-1',
        amount: 130,
        paidAmount: 130,
        status: 'paid',
        paidAt: DateTime(2026, 4, 10),
        weekStart: DateTime(2026, 4, 6),
        weekEnd: DateTime(2026, 4, 12),
      ),
    ];
    final attendance = <AttendanceEntry>[
      AttendanceEntry(
        seasonId: 'season-1',
        playerId: 'p1',
        attendedOn: DateTime(2026, 3, 31),
        status: AttendanceStatus.present,
      ),
      AttendanceEntry(
        seasonId: 'season-1',
        playerId: 'p1',
        attendedOn: DateTime(2026, 4, 2),
        status: AttendanceStatus.present,
      ),
      AttendanceEntry(
        seasonId: 'season-1',
        playerId: 'p1',
        attendedOn: DateTime(2026, 4, 8),
        status: AttendanceStatus.present,
      ),
      AttendanceEntry(
        seasonId: 'season-1',
        playerId: 'p2',
        attendedOn: DateTime(2026, 3, 31),
        status: AttendanceStatus.present,
      ),
      AttendanceEntry(
        seasonId: 'season-1',
        playerId: 'p2',
        attendedOn: DateTime(2026, 4, 7),
        status: AttendanceStatus.present,
      ),
      AttendanceEntry(
        seasonId: 'season-1',
        playerId: 'p2',
        attendedOn: DateTime(2026, 4, 9),
        status: AttendanceStatus.present,
      ),
      AttendanceEntry(
        seasonId: 'season-1',
        playerId: 'p2',
        attendedOn: DateTime(2026, 4, 10),
        status: AttendanceStatus.present,
      ),
      AttendanceEntry(
        seasonId: 'season-1',
        playerId: 'p2',
        attendedOn: DateTime(2026, 4, 14),
        status: AttendanceStatus.present,
      ),
      AttendanceEntry(
        seasonId: 'season-1',
        playerId: 'p2',
        attendedOn: DateTime(2026, 4, 15),
        status: AttendanceStatus.present,
      ),
    ];

    final debts = calculatePlayerDebtCounts(
      players: players,
      paymentsInRange: payments,
      attendanceEntriesInRange: attendance,
      seasonStart: DateTime(2026, 2, 2),
      selectedWeekStart: DateTime(2026, 4, 13),
    );

    expect(debts['p1'], 1);
    expect(debts['p2'], 2);
  });

  test('adeudos son 0 antes del 30-03-2026 para todos', () {
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
      attendanceEntriesInRange: const <AttendanceEntry>[],
      seasonStart: DateTime(2026, 2, 2),
      selectedWeekStart: DateTime(2026, 3, 23),
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
