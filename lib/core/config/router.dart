import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../../features/attendance/attendance_page.dart';
import '../../features/auth/ui/login_page.dart';
import '../../features/awards/player_of_month_page.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/games/game_capture_page.dart';
import '../../features/games/game_detail_page.dart';
import '../../features/games/game_stats_page.dart';
import '../../features/games/games_page.dart';
import '../../features/games/stats_capture_page.dart';
import '../../features/payments/payments_page.dart';
import '../../features/payments/ui/weekly_summary_page.dart';
import '../../features/players/player_data_quality_page.dart';
import '../../features/players/player_form_page.dart';
import '../../features/players/player_profile_page.dart';
import '../../features/players/combine_rankings_page.dart';
import '../../features/seasons/season_detail_page.dart';
import '../../features/players/players_list_page.dart';
import '../../features/seasons/season_picker_page.dart';
import '../../features/uniforms/uniforms_requirements_page.dart';
import '../../features/uniforms/uniforms_page.dart';
import '../../features/uniforms/uniform_data_quality_page.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  ref.watch(authStateChangesProvider);
  final profileAsync = ref.watch(currentProfileProvider);

  final authNotifier = AuthStateNotifier(
    Supabase.instance.client.auth.onAuthStateChange,
  );
  ref.onDispose(authNotifier.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final isLoggedIn = Supabase.instance.client.auth.currentSession != null;
      final isOnLogin = state.matchedLocation == '/login';
      final isOnLoading = state.matchedLocation == '/loading';
      final isOnProfileMissing = state.matchedLocation == '/profile-missing';

      if (!isLoggedIn) {
        return isOnLogin ? null : '/login';
      }

      if (profileAsync.isLoading) {
        return isOnLoading ? null : '/loading';
      }

      final profile = profileAsync.valueOrNull;
      if (profile == null) {
        return isOnProfileMissing ? null : '/profile-missing';
      }

      if (isOnLogin || isOnLoading || isOnProfileMissing) {
        return '/';
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/loading',
        builder: (context, state) => const LoadingPage(),
      ),
      GoRoute(
        path: '/profile-missing',
        builder: (context, state) => const ProfileMissingPage(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const DashboardPage(),
      ),
      GoRoute(
        // Legacy alias for historical links/bookmarks.
        path: '/season',
        redirect: (context, state) => '/temporada',
      ),
      GoRoute(
        path: '/temporada',
        builder: (context, state) => const SeasonPickerPage(),
      ),
      GoRoute(
        // Legacy alias for historical links/bookmarks.
        path: '/season/:id',
        redirect: (context, state) =>
            '/temporada/${state.pathParameters['id']!}',
      ),
      GoRoute(
        path: '/temporada/:id',
        builder: (context, state) => SeasonDetailPage(
          seasonId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/players',
        builder: (context, state) => const PlayersListPage(),
      ),
      GoRoute(
        path: '/players/new',
        builder: (context, state) => const PlayerFormPage(),
      ),
      GoRoute(
        path: '/players/data-quality',
        builder: (context, state) => PlayerDataQualityPage(
          missingFieldFilter: state.uri.queryParameters['missingField'],
        ),
      ),
      GoRoute(
        path: '/players/:id',
        builder: (context, state) => PlayerProfilePage(
          playerId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/players/:id/edit',
        builder: (context, state) => PlayerFormPage(
          playerId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/combine-rankings',
        builder: (context, state) => const CombineRankingsPage(),
      ),
      GoRoute(
        path: '/payments',
        builder: (context, state) => const PaymentsPage(),
      ),
      GoRoute(
        path: '/payments/weekly-summary',
        builder: (context, state) => WeeklySummaryPage(
          initialWeekStart: DateTime.tryParse(
            state.uri.queryParameters['weekStart'] ?? '',
          ),
          mode: (state.uri.queryParameters['mode'] ?? 'training') == 'uniform'
              ? PaymentsSummaryMode.uniform
              : PaymentsSummaryMode.training,
          initialCampaignId: state.uri.queryParameters['campaignId'],
        ),
      ),
      GoRoute(
        path: '/payments/attendance',
        builder: (context, state) => AttendancePage(
          initialDate: DateTime.tryParse(
            state.uri.queryParameters['date'] ?? '',
          ),
        ),
      ),
      GoRoute(
        // Legacy alias for historical links/bookmarks.
        path: '/uniforms',
        builder: (context, state) => const UniformsPage(),
      ),
      GoRoute(
        path: '/uniformes',
        builder: (context, state) => const UniformsPage(),
      ),
      GoRoute(
        // Legacy alias for historical links/bookmarks.
        path: '/uniforms/requirements',
        builder: (context, state) => const UniformsRequirementsPage(),
      ),
      GoRoute(
        path: '/uniformes/requisitos',
        builder: (context, state) => const UniformsRequirementsPage(),
      ),
      GoRoute(
        path: '/uniformes/calidad',
        builder: (context, state) => UniformDataQualityPage(
          seasonId: state.uri.queryParameters['season'],
          initialMissing: state.uri.queryParameters['missing'],
          numberRequired: state.uri.queryParameters['numberRequired'] == '1',
        ),
      ),
      GoRoute(
        // Legacy alias for historical links/bookmarks.
        path: '/games',
        redirect: (context, state) => '/partidos',
      ),
      GoRoute(
        path: '/partidos',
        builder: (context, state) => const GamesPage(),
      ),
      GoRoute(
        path: '/games/:id',
        builder: (context, state) => GameDetailPage(
          gameId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/games/:id/stats/:type',
        builder: (context, state) => StatsCapturePage(
          gameId: state.pathParameters['id']!,
          type: state.pathParameters['type']!,
        ),
      ),
      GoRoute(
        path: '/games/:id/capture',
        builder: (context, state) => GameCapturePage(
          gameId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/games/:id/play-stats',
        builder: (context, state) => GameStatsPage(
          gameId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/awards',
        builder: (context, state) => const PlayerOfMonthPage(),
      ),
    ],
  );
});

class AuthStateNotifier extends ChangeNotifier {
  AuthStateNotifier(Stream<AuthState> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class ProfileMissingPage extends StatelessWidget {
  const ProfileMissingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil faltante')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Perfil faltante',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tu usuario no tiene perfil en la tabla profiles. Pide al super_admin que te habilite.',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              },
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
