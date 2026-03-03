class Award {
  const Award({
    required this.id,
    required this.seasonId,
    required this.month,
    required this.playerId,
    required this.playerName,
    this.reason,
    this.createdAt,
  });

  final String id;
  final String seasonId;
  final DateTime month;
  final String playerId;
  final String playerName;
  final String? reason;
  final DateTime? createdAt;

  factory Award.fromMap(Map<String, dynamic> map) {
    final player = map['players'] as Map<String, dynamic>?;
    final firstName = player?['first_name'] as String?;
    final lastName = player?['last_name'] as String?;
    final jersey = player?['jersey_number'];
    final name = (firstName != null || lastName != null)
        ? '#${jersey ?? '-'} ${[
            firstName,
            lastName
          ].whereType<String>().join(' ').trim()}'
        : (map['player_id'] as String);

    return Award(
      id: map['id'] as String,
      seasonId: map['season_id'] as String,
      month: DateTime.parse(map['month'] as String),
      playerId: map['player_id'] as String,
      playerName: name,
      reason: map['reason'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }
}

class AwardPlayerOption {
  const AwardPlayerOption({
    required this.id,
    required this.jerseyNumber,
    required this.firstName,
    required this.lastName,
  });

  final String id;
  final int jerseyNumber;
  final String firstName;
  final String lastName;

  String get label => '#$jerseyNumber $firstName $lastName';

  factory AwardPlayerOption.fromMap(Map<String, dynamic> map) {
    return AwardPlayerOption(
      id: map['id'] as String,
      jerseyNumber: map['jersey_number'] as int,
      firstName: map['first_name'] as String,
      lastName: map['last_name'] as String,
    );
  }
}
