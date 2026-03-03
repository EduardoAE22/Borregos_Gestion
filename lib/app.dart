import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/router.dart';
import 'core/theme/theme.dart';
import 'core/ui/app_scroll_behavior.dart';

class BorregosApp extends ConsumerWidget {
  const BorregosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'Borregos Gestion',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      scrollBehavior: const AppScrollBehavior(),
      routerConfig: router,
    );
  }
}
