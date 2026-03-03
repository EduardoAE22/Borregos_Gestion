import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/app_strings.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.selectedNavIndex,
    this.actions,
  });

  final String title;
  final Widget body;
  final int? selectedNavIndex;
  final List<Widget>? actions;

  static const List<String> _bottomRoutes = [
    '/players',
    '/payments',
    '/awards',
  ];

  void _go(BuildContext context, String route) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text('Borregos Gestion'),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text(AppStrings.dashboard),
              onTap: () => _go(context, '/'),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text(AppStrings.season),
              onTap: () => _go(context, '/season'),
            ),
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: const Text(AppStrings.players),
              onTap: () => _go(context, '/players'),
            ),
            ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: const Text(AppStrings.payments),
              onTap: () => _go(context, '/payments'),
            ),
            ListTile(
              leading: const Icon(Icons.sports_football_outlined),
              title: const Text(AppStrings.games),
              onTap: () => _go(context, '/partidos'),
            ),
            ListTile(
              leading: const Icon(Icons.checkroom_outlined),
              title: const Text(AppStrings.uniforms),
              onTap: () => _go(context, '/uniformes'),
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events_outlined),
              title: const Text(AppStrings.awards),
              onTap: () => _go(context, '/awards'),
            ),
          ],
        ),
      ),
      body: SafeArea(child: body),
      bottomNavigationBar: selectedNavIndex == null
          ? null
          : NavigationBar(
              selectedIndex: selectedNavIndex!,
              onDestinationSelected: (index) =>
                  context.go(_bottomRoutes[index]),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.groups_outlined),
                  label: AppStrings.players,
                ),
                NavigationDestination(
                  icon: Icon(Icons.payments_outlined),
                  label: AppStrings.payments,
                ),
                NavigationDestination(
                  icon: Icon(Icons.emoji_events_outlined),
                  label: AppStrings.awards,
                ),
              ],
            ),
    );
  }
}
