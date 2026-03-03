class GamePlay {
  const GamePlay({
    this.id,
    required this.gameId,
    required this.half,
    required this.unit,
    this.down,
    this.distanceYards,
    required this.yards,
    required this.points,
    this.description,
    this.notes,
    this.qbPlayerId,
    this.receiverPlayerId,
    required this.isTarget,
    required this.isCompletion,
    required this.isDrop,
    required this.isPassTd,
    required this.isRush,
    required this.isRushTd,
    this.defenderPlayerId,
    required this.isSack,
    required this.isTackleFlag,
    required this.isInterception,
    required this.isPick6,
    required this.isPassDefended,
    required this.isPenalty,
    this.penaltyText,
    this.createdAt,
    this.qbName,
    this.receiverName,
    this.defenderName,
  });

  final String? id;
  final String gameId;
  final int half;
  final String unit; // ofensiva | defensiva
  final int? down;
  final int? distanceYards;
  final int yards;
  final int points;
  final String? description;
  final String? notes;
  final String? qbPlayerId;
  final String? receiverPlayerId;
  final bool isTarget;
  final bool isCompletion;
  final bool isDrop;
  final bool isPassTd;
  final bool isRush;
  final bool isRushTd;
  final String? defenderPlayerId;
  final bool isSack;
  final bool isTackleFlag;
  final bool isInterception;
  final bool isPick6;
  final bool isPassDefended;
  final bool isPenalty;
  final String? penaltyText;
  final DateTime? createdAt;
  final String? qbName;
  final String? receiverName;
  final String? defenderName;

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'game_id': gameId,
      'half': half,
      'unit': unit,
      'down': down,
      'distance_yards': distanceYards,
      'yards': yards,
      'points': points,
      'description': description,
      'notes': notes,
      'qb_player_id': qbPlayerId,
      'receiver_player_id': receiverPlayerId,
      'is_target': isTarget,
      'is_completion': isCompletion,
      'is_drop': isDrop,
      'is_pass_td': isPassTd,
      'is_rush': isRush,
      'is_rush_td': isRushTd,
      'defender_player_id': defenderPlayerId,
      'is_sack': isSack,
      'is_tackle_flag': isTackleFlag,
      'is_interception': isInterception,
      'is_pick6': isPick6,
      'is_pass_defended': isPassDefended,
      'is_penalty': isPenalty,
      'penalty_text': penaltyText,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory GamePlay.fromMap(Map<String, dynamic> map) {
    String? playerDisplay(Map<String, dynamic>? player) {
      if (player == null) return null;
      final jersey = player['jersey_number'] ?? '-';
      final first = (player['first_name'] as String?) ?? '';
      final last = (player['last_name'] as String?) ?? '';
      return '#$jersey $first $last'.trim();
    }

    return GamePlay(
      id: map['id'] as String?,
      gameId: map['game_id'] as String,
      half: (map['half'] as num).toInt(),
      unit: map['unit'] as String,
      down: (map['down'] as num?)?.toInt(),
      distanceYards: (map['distance_yards'] as num?)?.toInt(),
      yards: (map['yards'] as num?)?.toInt() ?? 0,
      points: (map['points'] as num?)?.toInt() ?? 0,
      description: map['description'] as String?,
      notes: map['notes'] as String?,
      qbPlayerId: map['qb_player_id'] as String?,
      receiverPlayerId: map['receiver_player_id'] as String?,
      isTarget: (map['is_target'] as bool?) ?? false,
      isCompletion: (map['is_completion'] as bool?) ?? false,
      isDrop: (map['is_drop'] as bool?) ?? false,
      isPassTd: (map['is_pass_td'] as bool?) ?? false,
      isRush: (map['is_rush'] as bool?) ?? false,
      isRushTd: (map['is_rush_td'] as bool?) ?? false,
      defenderPlayerId: map['defender_player_id'] as String?,
      isSack: (map['is_sack'] as bool?) ?? false,
      isTackleFlag: (map['is_tackle_flag'] as bool?) ?? false,
      isInterception: (map['is_interception'] as bool?) ?? false,
      isPick6: (map['is_pick6'] as bool?) ?? false,
      isPassDefended: (map['is_pass_defended'] as bool?) ?? false,
      isPenalty: (map['is_penalty'] as bool?) ?? false,
      penaltyText: map['penalty_text'] as String?,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.parse(map['created_at'] as String),
      qbName: playerDisplay(map['qb_player'] as Map<String, dynamic>?),
      receiverName:
          playerDisplay(map['receiver_player'] as Map<String, dynamic>?),
      defenderName:
          playerDisplay(map['defender_player'] as Map<String, dynamic>?),
    );
  }
}

const List<int> kPlayPointsOptions = <int>[0, 1, 2, 3, 6, 7, 8];

String halfLabel(int half) => half == 2 ? 'Segundo tiempo' : 'Primer tiempo';
String unitLabel(String unit) => unit == 'defensiva' ? 'Defensiva' : 'Ofensiva';
