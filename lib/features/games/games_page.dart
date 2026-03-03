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
import '../seasons/providers/seasons_providers.dart';
import 'providers/games_providers.dart';

String _gameTypeLabel(String type) {
  switch (type) {
    case 'interno':
      return 'Interno';
    case 'amistoso':
      return 'Amistoso';
    default:
      return 'Partido';
  }
}

class GamesPage extends ConsumerStatefulWidget {
  const GamesPage({super.key});

  @override
  ConsumerState<GamesPage> createState() => _GamesPageState();
}

class _GamesPageState extends ConsumerState<GamesPage>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);

    return AppScaffold(
      title: AppStrings.games,
      body: WatermarkedBody(
        child: profileAsync.when(
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
                          'Partidos: amistosos e internos (fuera de temporada)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: canWrite
                            ? () => _openCreateTypeSheet(context)
                            : null,
                        icon: const Icon(Icons.add_box_outlined),
                        label: const Text('Crear partido'),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Amistosos'),
                    Tab(text: 'Internos'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _GlobalGamesList(
                        gameType: 'amistoso',
                        canWrite: canWrite,
                      ),
                      _GlobalGamesList(
                        gameType: 'interno',
                        canWrite: canWrite,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const Loading(message: 'Cargando permisos...'),
          error: (error, _) => Center(child: Text('Error: $error')),
        ),
      ),
    );
  }

  Future<void> _openCreateTypeSheet(BuildContext context) async {
    final selectedType = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            _CreateTypeOption(
              type: 'amistoso',
              title: 'Amistoso',
              subtitle: 'Partido vs otro equipo fuera de torneo',
            ),
            _CreateTypeOption(
              type: 'interno',
              title: 'Interno',
              subtitle: 'Scrimmage / equipo dividido',
            ),
          ],
        ),
      ),
    );

    if (!context.mounted || selectedType == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _GlobalGameFormSheet(gameType: selectedType),
    );
    ref.invalidate(globalGamesByTypeProvider(selectedType));
  }
}

class _CreateTypeOption extends StatelessWidget {
  const _CreateTypeOption({
    required this.type,
    required this.title,
    required this.subtitle,
  });

  final String type;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.sports_football_outlined),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: () => Navigator.of(context).pop(type),
    );
  }
}

class _GlobalGamesList extends ConsumerWidget {
  const _GlobalGamesList({
    required this.gameType,
    required this.canWrite,
  });

  final String gameType;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamesAsync = ref.watch(globalGamesByTypeProvider(gameType));

    return gamesAsync.when(
      data: (games) {
        if (games.isEmpty) {
          return EmptyState(
            title: 'Sin ${_gameTypeLabel(gameType).toLowerCase()}',
            message:
                'Crea el primer partido ${_gameTypeLabel(gameType).toLowerCase()}.',
            icon: Icons.sports_football_outlined,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
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
                  spacing: 6,
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
                                          Navigator.of(context).pop(false),
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
                              ref.invalidate(
                                  globalGamesByTypeProvider(gameType));
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
      loading: () => const Loading(message: 'Cargando partidos...'),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }
}

class _GlobalGameFormSheet extends ConsumerStatefulWidget {
  const _GlobalGameFormSheet({
    required this.gameType,
  });

  final String gameType;

  @override
  ConsumerState<_GlobalGameFormSheet> createState() =>
      _GlobalGameFormSheetState();
}

class _GlobalGameFormSheetState extends ConsumerState<_GlobalGameFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _opponentController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.gameType == 'interno') {
      _opponentController.text = 'Interno A vs Interno B';
    }
  }

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
      final activeSeasonId = ref.read(activeSeasonIdProvider) ??
          (await ref.read(activeSeasonProvider.future))?.id;
      if (activeSeasonId == null || activeSeasonId.trim().isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'No hay temporada activa para asignar roster al partido.')),
        );
        return;
      }

      final repo = ref.read(gamesRepoProvider);
      if (widget.gameType == 'interno') {
        await repo.createGameInternal(
          gameDate: _date,
          rosterSeasonId: activeSeasonId,
          opponent: _opponentController.text.trim().isEmpty
              ? 'Interno A vs Interno B'
              : _opponentController.text.trim(),
        );
      } else {
        await repo.createGameFriendly(
          opponent: _opponentController.text.trim(),
          gameDate: _date,
          rosterSeasonId: activeSeasonId,
          location: _locationController.text.trim().isEmpty
              ? null
              : _locationController.text.trim(),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } on PostgrestException catch (e) {
      AppLogger.supabaseError(e, scope: 'GamesGlobal.create');
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
                Text(
                  'Nuevo ${_gameTypeLabel(widget.gameType).toLowerCase()}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _opponentController,
                  decoration: InputDecoration(
                    labelText: widget.gameType == 'interno'
                        ? 'Nombre del interno'
                        : 'Rival',
                  ),
                  validator: (value) {
                    if (widget.gameType == 'interno') return null;
                    return (value ?? '').trim().isEmpty ? 'Requerido' : null;
                  },
                ),
                if (widget.gameType == 'amistoso') ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _locationController,
                    decoration:
                        const InputDecoration(labelText: 'Sede (opcional)'),
                  ),
                ],
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
