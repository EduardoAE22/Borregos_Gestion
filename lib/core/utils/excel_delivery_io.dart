import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<String> deliverExcelBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);

  await Share.shareXFiles(
    [
      XFile(file.path, mimeType: mimeType, name: fileName),
    ],
    text: 'Lista de tallas',
  );

  return 'Archivo guardado en: ${file.path}';
}
