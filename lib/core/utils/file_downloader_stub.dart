import 'dart:typed_data';

Future<void> downloadBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  throw UnsupportedError('Descarga directa disponible en web.');
}
