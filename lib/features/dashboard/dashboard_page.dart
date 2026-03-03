import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/player_profile_requirements.dart';
import '../../core/theme/brand.dart';
import '../../core/ui/app_strings.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/formatters.dart';
import 'dashboard_payments_summary.dart';
import '../auth/providers/auth_providers.dart';
import '../awards/domain/award.dart';
import '../awards/providers/awards_providers.dart';
import '../games/domain/game.dart';
import '../games/providers/games_providers.dart';
import '../payments/domain/payment.dart';
import '../payments/providers/payments_providers.dart';
import '../players/domain/player.dart';
import '../players/domain/player_completeness.dart';
import '../players/providers/players_providers.dart';
import '../seasons/providers/seasons_providers.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/background_watermark.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  @override
  void initState() {
    super.initState();
    AppLogger.info('Nav',
        'Entrando a DashboardPage @ ${DateTime.now().toIso8601String()}');
  }

  @override
  Widget build(BuildContext context) {
    final seasonAsync = ref.watch(activeSeasonProvider);
    final profileAsync = ref.watch(currentProfileProvider);
    final playersAsync = ref.watch(playersByActiveSeasonProvider);
    final paymentsAsync = ref.watch(paymentsByActiveSeasonProvider);
    final gamesAsync = ref.watch(gamesByActiveSeasonProvider);
    final awardsAsync = ref.watch(awardsByActiveSeasonProvider);

    return AppScaffold(
      title: AppStrings.dashboard,
      actions: [
        IconButton(
          tooltip: 'Cerrar sesion',
          onPressed: () async {
            final navigator = Navigator.of(context);
            if (navigator.canPop()) navigator.pop();
            await ref.read(authRepoProvider).logout();
            if (context.mounted) context.go('/login');
          },
          icon: const Icon(Icons.logout),
        ),
      ],
      body: WatermarkedBody(
        child: seasonAsync.when(
          data: (season) {
            if (season == null) {
              return EmptyState(
                title: 'Sin temporada activa',
                message: 'Selecciona una temporada para usar los modulos.',
                icon: Icons.calendar_month_outlined,
                actionLabel: 'Seleccionar temporada',
                onAction: () => context.go('/season'),
              );
            }

            if (playersAsync.isLoading ||
                paymentsAsync.isLoading ||
                gamesAsync.isLoading ||
                awardsAsync.isLoading ||
                profileAsync.isLoading) {
              return const Loading(message: 'Cargando resumen...');
            }

            final players = playersAsync.valueOrNull ?? const <Player>[];
            final payments = paymentsAsync.valueOrNull ?? const <PaymentRow>[];
            final games = gamesAsync.valueOrNull ?? const <Game>[];
            final awards = awardsAsync.valueOrNull ?? const <Award>[];
            final profile = profileAsync.valueOrNull;

            final activePlayers = players.where((p) => p.isActive).length;
            final inactivePlayers = players.length - activePlayers;
            final totalPlayers = players.length;
            final completePlayers =
                players.where(PlayerCompletenessHelper.isComplete).length;
            final incompletePlayers = totalPlayers - completePlayers;
            final topMissing =
                PlayerCompletenessHelper.topMissing(players, limit: 3);

            final now = DateTime.now();
            final paymentsSummary = buildDashboardPaymentsSummary(
              payments: payments,
              now: now,
            );

            final today = DateTime(now.year, now.month, now.day);
            final upcomingGames = games.where((g) {
              final d =
                  DateTime(g.gameDate.year, g.gameDate.month, g.gameDate.day);
              return !d.isBefore(today);
            }).toList()
              ..sort((a, b) => a.gameDate.compareTo(b.gameDate));
            final nextGames = upcomingGames.take(2).toList();

            final monthAward = awards.where(
                (a) => a.month.year == now.year && a.month.month == now.month);
            final awardOfMonth = monthAward.isEmpty ? null : monthAward.first;

            return Stack(
              children: [
                const _DashboardBackdrop(),
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _StaggerReveal(
                      delayMs: 30,
                      child: _HeaderCard(
                        seasonName: season.name,
                        profileName: profile?.fullName ?? 'Usuario',
                      ),
                    ),
                    const SizedBox(height: 14),
                    GridView.count(
                      crossAxisCount:
                          MediaQuery.of(context).size.width > 980 ? 4 : 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.15,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _StaggerReveal(
                          delayMs: 120,
                          child: _SummaryCard(
                            icon: Icons.groups_outlined,
                            title: AppStrings.players,
                            line1: 'Total: $totalPlayers',
                            line2:
                                'Completos: $completePlayers  •  Incompletos: $incompletePlayers',
                            detailsWidget: _PlayersCardDetails(
                              activePlayers: activePlayers,
                              inactivePlayers: inactivePlayers,
                              topMissing: topMissing,
                            ),
                            route: '/players/data-quality',
                          ),
                        ),
                        _StaggerReveal(
                          delayMs: 180,
                          child: _SummaryCard(
                            icon: Icons.payments_outlined,
                            title: AppStrings.payments,
                            line1:
                                'Mes actual: ${AppFormatters.money(paymentsSummary.totalPaidMonth)}',
                            line2:
                                'Pagos registrados: ${paymentsSummary.registeredPaymentsCount}',
                            route: '/payments',
                          ),
                        ),
                        _StaggerReveal(
                          delayMs: 240,
                          child: _SummaryCard(
                            icon: Icons.sports_football_outlined,
                            title: AppStrings.games,
                            line1: nextGames.isEmpty
                                ? 'Sin partidos'
                                : '${AppFormatters.date(nextGames.first.gameDate)} vs ${nextGames.first.opponent}',
                            line2: nextGames.length > 1
                                ? '${AppFormatters.date(nextGames[1].gameDate)} vs ${nextGames[1].opponent}'
                                : 'Sin segundo partido cercano',
                            route: '/partidos',
                          ),
                        ),
                        _StaggerReveal(
                          delayMs: 300,
                          child: _SummaryCard(
                            icon: Icons.emoji_events_outlined,
                            title: AppStrings.awards,
                            line1: awardOfMonth == null
                                ? 'Sin jugador del mes'
                                : 'Mes actual: ${awardOfMonth.playerName}',
                            line2: awardOfMonth == null
                                ? 'Registra un reconocimiento para este mes'
                                : (awardOfMonth.reason?.trim().isNotEmpty ??
                                        false)
                                    ? awardOfMonth.reason!
                                    : 'Reconocimiento registrado',
                            route: '/awards',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
          loading: () => const Loading(message: 'Cargando temporada...'),
          error: (error, stack) => Center(child: Text('Error: $error')),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.seasonName,
    required this.profileName,
  });

  final String seasonName;
  final String profileName;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF181818), Color(0xFF101010)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: BrandColors.gold.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sede Progreso',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Container(
                    width: 110,
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [BrandColors.gold, Colors.transparent]),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Temporada activa: $seasonName',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text('Bienvenido, $profileName',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 104,
              height: 104,
              child: Image.asset(
                'assets/branding/borregos_logo.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.emoji_events_outlined, size: 64),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.line1,
    required this.line2,
    required this.route,
    this.detailsWidget,
  });

  final IconData icon;
  final String title;
  final String line1;
  final String line2;
  final String route;
  final Widget? detailsWidget;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: BrandColors.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: BrandColors.gold.withValues(alpha: 0.45)),
              ),
              child: Icon(icon, color: BrandColors.goldSoft, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              line1,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(line2,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            if (detailsWidget != null) ...[
              const SizedBox(height: 8),
              Flexible(child: detailsWidget!),
            ] else
              const Spacer(),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: () => context.go(route),
                child: const Text('Ver'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardBackdrop extends StatelessWidget {
  const _DashboardBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    BrandColors.gold.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    BrandColors.gold.withValues(alpha: 0.17),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayersCardDetails extends StatelessWidget {
  const _PlayersCardDetails({
    required this.activePlayers,
    required this.inactivePlayers,
    required this.topMissing,
  });

  final int activePlayers;
  final int inactivePlayers;
  final List<MapEntry<String, int>> topMissing;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activos: $activePlayers  •  Inactivos: $inactivePlayers',
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text('Faltantes mas comunes:',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          if (topMissing.isEmpty)
            Text('Sin faltantes', style: Theme.of(context).textTheme.bodySmall)
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: topMissing.map((entry) {
                final label = PlayerProfileRequirements.labelFor(entry.key);
                return ActionChip(
                  label: Text('$label (${entry.value})'),
                  onPressed: () {
                    context.go(
                      '/players/data-quality?missingField=${Uri.encodeComponent(entry.key)}',
                    );
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _StaggerReveal extends StatefulWidget {
  const _StaggerReveal({
    required this.child,
    required this.delayMs,
  });

  final Widget child;
  final int delayMs;

  @override
  State<_StaggerReveal> createState() => _StaggerRevealState();
}

class _StaggerRevealState extends State<_StaggerReveal> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Timer(Duration(milliseconds: widget.delayMs), () {
      if (!mounted) return;
      setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        offset: _visible ? Offset.zero : const Offset(0, 0.04),
        child: widget.child,
      ),
    );
  }
}
