import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/ui/app_strings.dart';
import '../../core/utils/logger.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/background_watermark.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading.dart';
import '../auth/providers/auth_providers.dart';
import '../games/providers/games_providers.dart';
import 'providers/seasons_providers.dart';

class SeasonDetailPage extends ConsumerStatefulWidget {
  const SeasonDetailPage({
    super.key,
    required this.seasonId,
  });

  final String seasonId;

  @override
  ConsumerState<SeasonDetailPage> createState() => _SeasonDetailPageState();
}

class _SeasonDetailPageState extends ConsumerState<SeasonDetailPage> {
  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final seasonsAsync = ref.watch(seasonsListProvider);

    return AppScaffold(
      title: AppStrings.season,
      body: WatermarkedBody(
        child: seasonsAsync.when(
          data: (seasons) {
            final season =
                seasons.where((s) => s.id == widget.seasonId).firstOrNull;
            if (season == null) {
              return const EmptyState(
                title: 'Temporada no encontrada',
                message: 'La temporada seleccionada no existe.',
                icon: Icons.calendar_month_outlined,
              );
            }

            return profileAsync.when(
              data: (profile) {
                final canWrite = profile?.canWriteGeneral ?? false;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Temporada: torneos (${season.name})',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: canWrite
                                ? () => _openTournamentGameForm(context,
                                    seasonId: season.id)
                                : null,
                            icon: const Icon(Icons.add_box_outlined),
                            label: const Text('Crear partido'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => context.go('/season'),
                            icon: const Icon(Icons.arrow_back_outlined),
                            label: const Text('Volver'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _TournamentGamesTab(
                        seasonId: season.id,
                        canWrite: canWrite,
                        onChanged: () => _refreshTournament(season.id),
                        onCreate: () => _openTournamentGameForm(context,
                            seasonId: season.id),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Loading(message: 'Cargando permisos...'),
              error: (error, _) => Center(child: Text('Error: $error')),
            );
          },
          loading: () => const Loading(message: 'Cargando temporada...'),
          error: (error, _) => Center(child: Text('Error: $error')),
        ),
      ),
    );
  }

  Future<void> _openTournamentGameForm(
    BuildContext context, {
    required String seasonId,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TournamentGameFormSheet(seasonId: seasonId),
    );
    _refreshTournament(seasonId);
  }

  void _refreshTournament(String seasonId) {
    ref.invalidate(tournamentGamesBySeasonProvider(seasonId));
    ref.invalidate(gamesByActiveSeasonProvider);
  }
}

class _TournamentGamesTab extends ConsumerWidget {
  const _TournamentGamesTab({
    required this.seasonId,
    required this.canWrite,
    required this.onChanged,
    required this.onCreate,
  });

  final String seasonId;
  final bool canWrite;
  final VoidCallback onChanged;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamesAsync = ref.watch(tournamentGamesBySeasonProvider(seasonId));
    return Column(
      children: [
        if (!canWrite)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Modo solo lectura para este rol.'),
            ),
          ),
        Expanded(
          child: gamesAsync.when(
            data: (games) {
              if (games.isEmpty) {
                return EmptyState(
                  title: 'Sin partidos de torneo',
                  message:
                      'Crea el primer partido de torneo de esta temporada.',
                  icon: Icons.sports_football_outlined,
                  actionLabel: canWrite ? 'Crear partido' : null,
                  onAction: canWrite ? onCreate : null,
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                itemCount: games.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final game = games[index];
                  final date = game.gameDate.toIso8601String().split('T').first;
                  return Card(
                    child: ListTile(
                      onTap: () => context.push('/games/${game.id}'),
                      leading: const Icon(Icons.sports_football_outlined),
                      title: Text('vs ${game.opponent}'),
                      subtitle: Text('$date • ${game.location ?? 'Sin sede'}'),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          Text('${game.ourScore} - ${game.oppScore}'),
                          IconButton(
                            tooltip: 'Eliminar',
                            onPressed: canWrite && game.id != null
                                ? () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Eliminar partido'),
                                        content: Text(
                                            '¿Eliminar partido vs ${game.opponent}?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context)
                                                    .pop(false),
                                            child: const Text('Cancelar'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(true),
                                            child: const Text('Eliminar'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed != true) return;
                                    await ref
                                        .read(gamesRepoProvider)
                                        .deleteGame(game.id!);
                                    onChanged();
                                  }
                                : null,
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () =>
                const Loading(message: 'Cargando partidos del torneo...'),
            error: (error, _) => Center(child: Text('Error: $error')),
          ),
        ),
      ],
    );
  }
}

class _TournamentGameFormSheet extends ConsumerStatefulWidget {
  const _TournamentGameFormSheet({required this.seasonId});

  final String seasonId;

  @override
  ConsumerState<_TournamentGameFormSheet> createState() =>
      _TournamentGameFormSheetState();
}

class _TournamentGameFormSheetState
    extends ConsumerState<_TournamentGameFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _opponentController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _opponentController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;
    setState(() => _saving = true);
    try {
      await ref.read(gamesRepoProvider).createGameTournament(
            seasonId: widget.seasonId,
            opponent: _opponentController.text.trim(),
            gameDate: _date,
            location: _locationController.text.trim().isEmpty
                ? null
                : _locationController.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on PostgrestException catch (e) {
      AppLogger.supabaseError(e, scope: 'SeasonDetail.createTournamentGame');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Nuevo partido de torneo',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _opponentController,
                  decoration: const InputDecoration(labelText: 'Rival'),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(labelText: 'Sede'),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fecha del juego'),
                  subtitle: Text(_date.toIso8601String().split('T').first),
                  trailing: TextButton(
                      onPressed: _pickDate, child: const Text('Cambiar')),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Guardando...' : 'Guardar partido'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
