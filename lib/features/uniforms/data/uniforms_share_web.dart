import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> shareOrderExcel({
  required Uint8List bytes,
  required String filename,
  required String seasonName,
}) async {
  final _ = (bytes, seasonName);
  final message = 'Te envío el pedido de uniformes: $filename';
  await Clipboard.setData(ClipboardData(text: message));

  final encodedMessage = Uri.encodeComponent(message);
  final uri = Uri.parse('https://wa.me/?text=$encodedMessage');
  final opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
  if (!opened) {
    throw Exception('No se pudo abrir WhatsApp Web.');
  }
}
