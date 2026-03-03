import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> shareOrderExcel({
  required Uint8List bytes,
  required String filename,
  required String seasonName,
}) async {
  final _ = seasonName;
  final directory = await getTemporaryDirectory();
  final filePath = p.join(directory.path, filename);
  final file = File(filePath);
  await file.writeAsBytes(bytes, flush: true);

  await Share.shareXFiles(
    [XFile(file.path, name: filename)],
    text: 'Te envío el pedido de uniformes: $filename',
  );
}
