import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/ui/app_strings.dart';
import '../auth/providers/auth_providers.dart';
import '../seasons/providers/seasons_providers.dart';
import '../../core/utils/logger.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading.dart';
import 'data/awards_repo.dart';
import 'domain/award.dart';
import 'providers/awards_providers.dart';

class PlayerOfMonthPage extends ConsumerWidget {
  const PlayerOfMonthPage({super.key});

  Future<void> _openAssignSheet(
    BuildContext context,
    WidgetRef ref,
    String seasonId,
    Map<String, Award> existingByMonth,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AssignAwardSheet(
        seasonId: seasonId,
        existingByMonth: existingByMonth,
      ),
    );
    ref.invalidate(awardsListProvider(seasonId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final seasonAsync = ref.watch(activeSeasonProvider);

    return AppScaffold(
      title: AppStrings.playerOfMonth,
      selectedNavIndex: 2,
      body: profileAsync.when(
        data: (profile) {
          final canWrite = profile?.canWriteGeneral ?? false;

          return seasonAsync.when(
            data: (season) {
              if (season == null) {
                return const EmptyState(
                  title: 'Sin temporada activa',
                  message:
                      'Selecciona una temporada activa en /season para asignar jugador del mes.',
                  icon: Icons.calendar_month_outlined,
                );
              }

              final awardsAsync = ref.watch(awardsListProvider(season.id));

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Temporada activa: ${season.name}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: canWrite
                              ? () {
                                  final awards = awardsAsync.valueOrNull ??
                                      const <Award>[];
                                  final existingByMonth = <String, Award>{
                                    for (final a in awards)
                                      _monthKey(a.month): a,
                                  };

                                  _openAssignSheet(
                                    context,
                                    ref,
                                    season.id,
                                    existingByMonth,
                                  );
                                }
                              : null,
                          icon: const Icon(Icons.emoji_events_outlined),
                          label: const Text('Asignar'),
                        ),
                      ],
                    ),
                  ),
                  if (!canWrite)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Modo solo lectura para este rol.'),
                      ),
                    ),
                  Expanded(
                    child: awardsAsync.when(
                      data: (awards) {
                        if (awards.isEmpty) {
                          return const EmptyState(
                            title: 'Sin reconocimientos',
                            message: 'Aun no hay jugador del mes asignado.',
                            icon: Icons.emoji_events_outlined,
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: awards.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final award = awards[index];
                            final month =
                                award.month.toIso8601String().split('T').first;

                            return Card(
                              child: ListTile(
                                leading:
                                    const Icon(Icons.emoji_events_outlined),
                                title: Text(month),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(award.playerName),
                                    if ((award.reason ?? '').trim().isNotEmpty)
                                      Text('Motivo: ${award.reason}'),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                      loading: () =>
                          const Loading(message: 'Cargando asignaciones...'),
                      error: (error, stack) =>
                          Center(child: Text('Error: $error')),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Loading(message: 'Cargando temporada...'),
            error: (error, stack) => Center(child: Text('Error: $error')),
          );
        },
        loading: () => const Loading(message: 'Cargando permisos...'),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}

class _AssignAwardSheet extends ConsumerStatefulWidget {
  const _AssignAwardSheet({
    required this.seasonId,
    required this.existingByMonth,
  });

  final String seasonId;
  final Map<String, Award> existingByMonth;

  @override
  ConsumerState<_AssignAwardSheet> createState() => _AssignAwardSheetState();
}

class _AssignAwardSheetState extends ConsumerState<_AssignAwardSheet> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  DateTime _month = AwardsRepo.normalizeMonth(DateTime.now());
  String? _playerId;
  bool _saving = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;

    setState(() => _month = AwardsRepo.normalizeMonth(picked));
  }

  Future<void> _save() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || _playerId == null) return;

    setState(() => _saving = true);

    try {
      await ref.read(awardsRepoProvider).upsertAward(
            seasonId: widget.seasonId,
            monthDateFirstDay: _month,
            playerId: _playerId!,
            reason: _reasonController.text.trim().isEmpty
                ? null
                : _reasonController.text.trim(),
          );

      if (!mounted) return;
      Navigator.of(context).pop();
    } on PostgrestException catch (e) {
      AppLogger.supabaseError(e, scope: 'Awards.save');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playersAsync = ref.watch(awardPlayersProvider(widget.seasonId));
    final selectedMonthKey = _monthKey(_month);
    final existing = widget.existingByMonth[selectedMonthKey];

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
                Text('Asignar jugador del mes',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mes'),
                  subtitle: Text(selectedMonthKey),
                  trailing: TextButton(
                      onPressed: _pickMonth, child: const Text('Cambiar')),
                ),
                if (existing != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Ya existe asignacion para este mes (${existing.playerName}). Se actualizara.',
                    ),
                  ),
                playersAsync.when(
                  data: (players) {
                    if (players.isNotEmpty && _playerId == null) {
                      _playerId = players.first.id;
                    }

                    return DropdownButtonFormField<String>(
                      initialValue: _playerId,
                      decoration: const InputDecoration(labelText: 'Jugador'),
                      items: players
                          .map(
                            (p) => DropdownMenuItem(
                                value: p.id, child: Text(p.label)),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _playerId = value),
                      validator: (value) =>
                          value == null ? 'Selecciona jugador' : null,
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  ),
                  error: (error, stack) =>
                      Text('Error cargando jugadores: $error'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _reasonController,
                  maxLines: 2,
                  decoration:
                      const InputDecoration(labelText: 'Motivo (opcional)'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child:
                        Text(_saving ? 'Guardando...' : 'Guardar asignacion'),
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

String _monthKey(DateTime date) {
  final normalized = AwardsRepo.normalizeMonth(date);
  return normalized.toIso8601String().split('T').first;
}
