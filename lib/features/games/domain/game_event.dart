@Deprecated(
  'Modelo legacy no conectado a UI/rutas actuales. TODO(tech-debt): eliminar '
  'GameEvent y flujo game_events si se mantiene play-by-play v2 con game_plays.',
)
class GameEvent {
  const GameEvent({
    this.id,
    required this.gameId,
    required this.playerId,
    required this.period,
    required this.side,
    required this.eventType,
    this.yards,
    this.notes,
    this.createdAt,
    this.playerName,
  });

  final String? id;
  final String gameId;
  final String playerId;
  final int period; // 1 = primer tiempo, 2 = segundo tiempo
  final String side; // ofensa | defensa
  final String eventType;
  final int? yards;
  final String? notes;
  final DateTime? createdAt;
  final String? playerName;

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'game_id': gameId,
      'player_id': playerId,
      'period': period,
      'side': side,
      'event_type': eventType,
      'yards': yards,
      'notes': notes,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory GameEvent.fromMap(Map<String, dynamic> map) {
    final player = map['players'] as Map<String, dynamic>?;
    final fullName = player == null
        ? null
        : '#${player['jersey_number'] ?? '-'} ${(player['first_name'] ?? '')} ${(player['last_name'] ?? '')}'
            .trim();

    return GameEvent(
      id: map['id'] as String?,
      gameId: map['game_id'] as String,
      playerId: map['player_id'] as String,
      period: (map['period'] as num).toInt(),
      side: map['side'] as String,
      eventType: map['event_type'] as String,
      yards: (map['yards'] as num?)?.toInt(),
      notes: map['notes'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      playerName: fullName,
    );
  }
}

const List<String> kOffenseEventTypes = <String>[
  'pase_completo',
  'pase_incompleto',
  'drop',
  'corrida',
  'touchdown_pase',
  'touchdown_corrida',
  'centro_malo',
  'recepcion',
  'target',
];

const List<String> kDefenseEventTypes = <String>[
  'flag_pull',
  'sack',
  'intercepcion',
  'pase_defendido',
  'touchdown_defensa',
  'safety',
  'bloqueo',
  'pressure',
];

String sideLabel(String side) {
  return side == 'defensa' ? 'Defensa' : 'Ofensa';
}

String periodLabel(int period) {
  return period == 2 ? 'Segundo tiempo' : 'Primer tiempo';
}
