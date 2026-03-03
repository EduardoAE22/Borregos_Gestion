class Game {
  const Game({
    this.id,
    required this.seasonId,
    this.rosterSeasonId,
    required this.opponent,
    required this.gameDate,
    this.gameType = 'torneo',
    this.location,
    this.isTournament = false,
    this.ourScore = 0,
    this.oppScore = 0,
    this.createdAt,
  });

  final String? id;
  final String? seasonId;
  final String? rosterSeasonId;
  final String opponent;
  final DateTime gameDate;
  final String gameType;
  final String? location;
  final bool isTournament;
  final int ourScore;
  final int oppScore;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() {
    final normalizedType = _normalizeGameType(gameType);
    final map = <String, dynamic>{
      'season_id': seasonId,
      'roster_season_id': rosterSeasonId,
      'opponent': opponent,
      'game_date': gameDate.toIso8601String().split('T').first,
      'game_type': normalizedType,
      'location': location,
      'is_tournament': normalizedType == 'torneo',
      'our_score': ourScore,
      'opp_score': oppScore,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory Game.fromMap(Map<String, dynamic> map) {
    final rawType = (map['game_type'] as String?)?.trim();
    final gameType = rawType != null && rawType.isNotEmpty
        ? _normalizeGameType(rawType)
        : ((map['is_tournament'] as bool?) ?? false)
            ? 'torneo'
            : 'amistoso';

    return Game(
      id: map['id'] as String,
      seasonId: map['season_id'] as String?,
      rosterSeasonId: map['roster_season_id'] as String?,
      opponent: map['opponent'] as String,
      gameDate: DateTime.parse(map['game_date'] as String),
      gameType: gameType,
      location: map['location'] as String?,
      isTournament: gameType == 'torneo',
      ourScore: (map['our_score'] as int?) ?? 0,
      oppScore: (map['opp_score'] as int?) ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }
}

const List<String> kGameTypes = <String>['torneo', 'amistoso', 'interno'];

String gameTypeLabel(String type) {
  switch (type) {
    case 'torneo':
      return 'Torneo';
    case 'amistoso':
      return 'Amistosos';
    case 'interno':
      return 'Internos';
    default:
      return 'Torneo';
  }
}

String _normalizeGameType(String value) {
  final normalized = value.trim().toLowerCase();
  if (kGameTypes.contains(normalized)) return normalized;
  return 'torneo';
}
