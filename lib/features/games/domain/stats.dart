class RosterPlayer {
  const RosterPlayer({
    required this.id,
    required this.jerseyNumber,
    required this.firstName,
    required this.lastName,
  });

  final String id;
  final int jerseyNumber;
  final String firstName;
  final String lastName;

  String get displayName => '#$jerseyNumber $firstName $lastName';

  factory RosterPlayer.fromMap(Map<String, dynamic> map) {
    return RosterPlayer(
      id: map['id'] as String,
      jerseyNumber: map['jersey_number'] as int,
      firstName: map['first_name'] as String,
      lastName: map['last_name'] as String,
    );
  }
}

class QBStat {
  const QBStat({
    required this.gameId,
    required this.playerId,
    required this.playerName,
    this.completions = 0,
    this.incompletions = 0,
    this.passTds = 0,
    this.interceptions = 0,
    this.rushTds = 0,
  });

  final String gameId;
  final String playerId;
  final String playerName;
  final int completions;
  final int incompletions;
  final int passTds;
  final int interceptions;
  final int rushTds;

  factory QBStat.fromMap(Map<String, dynamic> map) {
    final player = map['players'] as Map<String, dynamic>?;
    final name = player == null
        ? map['player_id'] as String
        : '#${player['jersey_number'] ?? '-'} ${(player['first_name'] ?? '')} ${(player['last_name'] ?? '')}'
            .trim();

    return QBStat(
      gameId: map['game_id'] as String,
      playerId: map['player_id'] as String,
      playerName: name,
      completions: (map['completions'] as int?) ?? 0,
      incompletions: (map['incompletions'] as int?) ?? 0,
      passTds: (map['pass_tds'] as int?) ?? 0,
      interceptions: (map['interceptions'] as int?) ?? 0,
      rushTds: (map['rush_tds'] as int?) ?? 0,
    );
  }
}

class SkillStat {
  const SkillStat({
    required this.gameId,
    required this.playerId,
    required this.playerName,
    this.receptions = 0,
    this.targets = 0,
    this.recYards = 0,
    this.recTds = 0,
    this.drops = 0,
  });

  final String gameId;
  final String playerId;
  final String playerName;
  final int receptions;
  final int targets;
  final int recYards;
  final int recTds;
  final int drops;

  factory SkillStat.fromMap(Map<String, dynamic> map) {
    final player = map['players'] as Map<String, dynamic>?;
    final name = player == null
        ? map['player_id'] as String
        : '#${player['jersey_number'] ?? '-'} ${(player['first_name'] ?? '')} ${(player['last_name'] ?? '')}'
            .trim();

    return SkillStat(
      gameId: map['game_id'] as String,
      playerId: map['player_id'] as String,
      playerName: name,
      receptions: (map['receptions'] as int?) ?? 0,
      targets: (map['targets'] as int?) ?? 0,
      recYards: (map['rec_yards'] as int?) ?? 0,
      recTds: (map['rec_tds'] as int?) ?? 0,
      drops: (map['drops'] as int?) ?? 0,
    );
  }
}

class DefStat {
  const DefStat({
    required this.gameId,
    required this.playerId,
    required this.playerName,
    this.tackles = 0,
    this.sacks = 0,
    this.interceptions = 0,
    this.pick6 = 0,
    this.flags = 0,
  });

  final String gameId;
  final String playerId;
  final String playerName;
  final int tackles;
  final int sacks;
  final int interceptions;
  final int pick6;
  final int flags;

  factory DefStat.fromMap(Map<String, dynamic> map) {
    final player = map['players'] as Map<String, dynamic>?;
    final name = player == null
        ? map['player_id'] as String
        : '#${player['jersey_number'] ?? '-'} ${(player['first_name'] ?? '')} ${(player['last_name'] ?? '')}'
            .trim();

    return DefStat(
      gameId: map['game_id'] as String,
      playerId: map['player_id'] as String,
      playerName: name,
      tackles: (map['tackles'] as int?) ?? 0,
      sacks: (map['sacks'] as int?) ?? 0,
      interceptions: (map['interceptions'] as int?) ?? 0,
      pick6: (map['pick6'] as int?) ?? 0,
      flags: (map['flags'] as int?) ?? 0,
    );
  }
}
