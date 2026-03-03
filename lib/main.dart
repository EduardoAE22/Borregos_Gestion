import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/supabase_client.dart';
import 'core/ui/app_scroll_behavior.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await AppSupabase.initialize();
    runApp(const ProviderScope(child: BorregosApp()));
  } on MissingSupabaseConfigException catch (e) {
    runApp(ConfigMissingApp(message: e.message));
  }
}

class ConfigMissingApp extends StatelessWidget {
  const ConfigMissingApp({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      home: Scaffold(
        appBar: AppBar(title: const Text('Config faltante')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Config faltante',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(message),
              const SizedBox(height: 12),
              const Text(
                'Ejemplo:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const SelectableText(
                'flutter run -d chrome --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
