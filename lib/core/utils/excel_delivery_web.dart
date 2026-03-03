import 'dart:typed_data';

import 'file_downloader.dart';

Future<String> deliverExcelBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  await downloadBytes(bytes: bytes, fileName: fileName, mimeType: mimeType);
  return 'Archivo descargado: $fileName';
}
