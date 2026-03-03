import 'dart:typed_data';

Future<String> deliverExcelBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  throw UnsupportedError('Plataforma no soportada para exportar Excel.');
}
