class PlayerProfileFieldRequirement {
  const PlayerProfileFieldRequirement({
    required this.key,
    required this.sourceKey,
    required this.label,
    this.required = true,
    this.qualityChip = false,
  });

  final String key;
  final String sourceKey;
  final String label;
  final bool required;
  final bool qualityChip;
}

class PlayerProfileRequirements {
  PlayerProfileRequirements._();

  static const List<PlayerProfileFieldRequirement> fields =
      <PlayerProfileFieldRequirement>[
    PlayerProfileFieldRequirement(
      key: 'nombre',
      sourceKey: 'first_name',
      label: 'Nombre',
    ),
    PlayerProfileFieldRequirement(
      key: 'apellido',
      sourceKey: 'last_name',
      label: 'Apellido',
    ),
    PlayerProfileFieldRequirement(
      key: 'numero_jersey',
      sourceKey: 'jersey_number',
      label: '# Jersey',
    ),
    PlayerProfileFieldRequirement(
      key: 'posicion',
      sourceKey: 'position',
      label: 'Posición',
      qualityChip: true,
    ),
    PlayerProfileFieldRequirement(
      key: 'talla',
      sourceKey: 'jersey_size',
      label: 'Talla',
      qualityChip: true,
    ),
    PlayerProfileFieldRequirement(
      key: 'genero',
      sourceKey: 'uniform_gender',
      label: 'Género',
      qualityChip: true,
    ),
    PlayerProfileFieldRequirement(
      key: 'telefono',
      sourceKey: 'phone',
      label: 'Teléfono',
      qualityChip: true,
    ),
    PlayerProfileFieldRequirement(
      key: 'contacto_emergencia',
      sourceKey: 'emergency_contact',
      label: 'Contacto emergencia',
      qualityChip: true,
    ),
    PlayerProfileFieldRequirement(
      key: 'estatura_cm',
      sourceKey: 'height_cm',
      label: 'Estatura (cm)',
    ),
    PlayerProfileFieldRequirement(
      key: 'peso_kg',
      sourceKey: 'weight_kg',
      label: 'Peso (kg)',
    ),
    PlayerProfileFieldRequirement(
      key: 'foto',
      sourceKey: 'photo_path',
      label: 'Foto',
      qualityChip: true,
    ),
    PlayerProfileFieldRequirement(
      key: 'edad',
      sourceKey: 'age',
      label: 'Edad',
      required: false,
      qualityChip: true,
    ),
  ];

  static final List<String> requiredFieldKeys = fields
      .where((field) => field.required)
      .map((field) => field.key)
      .toList(growable: false);

  static final List<String> qualityChipFieldKeys = fields
      .where((field) => field.qualityChip)
      .map((field) => field.key)
      .toList(growable: false);

  static final Map<String, String> fieldLabels = <String, String>{
    for (final field in fields) field.key: field.label,
  };

  static String labelFor(String fieldKey) => fieldLabels[fieldKey] ?? fieldKey;

  static final Map<String, String> legacyKeyMap = <String, String>{
    'photo_url': 'foto',
    'photo_path': 'foto',
    'position': 'posicion',
    'emergency_contact': 'contacto_emergencia',
    'age': 'edad',
    'jersey_size': 'talla',
    'uniform_gender': 'genero',
    'phone': 'telefono',
    'first_name': 'nombre',
    'last_name': 'apellido',
    'jersey_number': 'numero_jersey',
    'height_cm': 'estatura_cm',
    'weight_kg': 'peso_kg',
  };

  static String normalizeKey(String fieldKey) {
    final key = fieldKey.trim();
    if (fieldLabels.containsKey(key)) return key;
    return legacyKeyMap[key] ?? key;
  }
}
