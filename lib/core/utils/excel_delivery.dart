import 'dart:typed_data';

import 'excel_delivery_stub.dart'
    if (dart.library.html) 'excel_delivery_web.dart'
    if (dart.library.io) 'excel_delivery_io.dart' as impl;

Future<String> deliverExcelBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) {
  return impl.deliverExcelBytes(
    bytes: bytes,
    fileName: fileName,
    mimeType: mimeType,
  );
}
