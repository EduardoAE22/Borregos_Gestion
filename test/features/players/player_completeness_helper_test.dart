import 'package:borregos_gestion/features/players/domain/player.dart';
import 'package:borregos_gestion/features/players/domain/player_completeness.dart';
import 'package:flutter_test/flutter_test.dart';

Player _player({
  required String id,
  required int jersey,
  String? position = 'WR',
  String? emergencyContact = 'Mama',
  String? photoUrl = 'https://example.com/photo.jpg',
  int? age,
}) {
  return Player(
    id: id,
    seasonId: 'season-1',
    jerseyNumber: jersey,
    firstName: 'Eduardo',
    lastName: 'Acosta',
    position: position,
    phone: '9991234567',
    emergencyContact: emergencyContact,
    photoUrl: photoUrl,
    age: age,
    heightCm: 175,
    weightKg: 78,
    isActive: true,
  );
}

void main() {
  test('detecta faltantes esperados y age no cuenta cuando es opcional', () {
    final p = _player(
      id: 'p1',
      jersey: 10,
      position: null,
      emergencyContact: '   ',
      photoUrl: null,
      age: null,
    );

    final missingLabels =
        PlayerCompletenessHelper.missingFieldLabelsForPlayer(p);
    final missingKeys = PlayerCompletenessHelper.missingFieldKeysForPlayer(p);

    expect(missingLabels, contains('Foto'));
    expect(missingLabels, contains('Posición'));
    expect(missingLabels, contains('Contacto emergencia'));
    expect(missingKeys, isNot(contains('edad')));
  });

  test('commonMissingCounts suma correctamente por campo', () {
    final p1 = _player(
      id: 'p1',
      jersey: 10,
      position: null,
      emergencyContact: '',
      photoUrl: null,
    );
    final p2 = _player(
      id: 'p2',
      jersey: 11,
      photoUrl: null,
    );
    final p3 = _player(
      id: 'p3',
      jersey: 12,
    );

    final counts = PlayerCompletenessHelper.commonMissingCounts([p1, p2, p3]);

    expect(counts['foto'], 2);
    expect(counts['posicion'], 1);
    expect(counts['contacto_emergencia'], 1);
  });
}
