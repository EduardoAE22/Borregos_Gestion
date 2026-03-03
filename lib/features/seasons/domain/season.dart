class Season {
  const Season({
    required this.id,
    required this.name,
    required this.startsOn,
    required this.endsOn,
    required this.isActive,
  });

  final String id;
  final String name;
  final DateTime startsOn;
  final DateTime endsOn;
  final bool isActive;

  factory Season.fromMap(Map<String, dynamic> map) {
    return Season(
      id: map['id'] as String,
      name: map['name'] as String,
      startsOn: DateTime.parse(map['starts_on'] as String),
      endsOn: DateTime.parse(map['ends_on'] as String),
      isActive: (map['is_active'] as bool?) ?? false,
    );
  }
}

class SeasonCreate {
  const SeasonCreate({
    required this.name,
    required this.startsOn,
    required this.endsOn,
  });

  final String name;
  final DateTime startsOn;
  final DateTime endsOn;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'starts_on': _asDate(startsOn),
      'ends_on': _asDate(endsOn),
    };
  }

  static String _asDate(DateTime date) =>
      DateTime(date.year, date.month, date.day)
          .toIso8601String()
          .split('T')
          .first;
}
