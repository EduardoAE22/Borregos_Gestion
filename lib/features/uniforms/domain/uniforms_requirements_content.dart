class UniformsRequirementsContent {
  UniformsRequirementsContent._();

  static const intro =
      'Estos son los requisitos solicitados por el proveedor para procesar uniformes y jerseys.';

  static const noColumnRule =
      'Columna No.: es un consecutivo por fila del pedido (1..N).';

  static const allowedAdultSizes = <String>[
    'XS',
    'S',
    'M',
    'L',
    'XL',
    '2XL',
    '3XL',
  ];

  static const allowedKidsSizes = <String>[
    '2',
    '4',
    '6',
    '8',
    '10',
    '12',
    '14',
    '16',
  ];

  static const allowedGenders = <String>[
    'H',
    'M',
    'Niña',
    'Niño',
  ];

  static const disclaimer =
      'Nota: puede haber variaciones por talla/género según disponibilidad del proveedor. '
      'El proveedor no se responsabiliza por errores de captura en talla, género o número.';
}
