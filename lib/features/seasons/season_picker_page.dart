import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/ui/app_strings.dart';
import '../auth/providers/auth_providers.dart';
import '../../core/utils/logger.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/background_watermark.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading.dart';
import 'domain/season.dart';
import 'providers/seasons_providers.dart';

class SeasonPickerPage extends ConsumerWidget {
  const SeasonPickerPage({super.key});

  Future<void> _openCreateSeasonSheet(
      BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateSeasonSheet(),
    );

    ref.invalidate(seasonsListProvider);
    ref.invalidate(activeSeasonProvider);
  }

  Future<void> _markActive(
      BuildContext context, WidgetRef ref, String seasonId) async {
    try {
      final action = ref.read(setActiveSeasonActionProvider);
      await action(seasonId);
    } on PostgrestException catch (e) {
      AppLogger.supabaseError(e, scope: 'SeasonPicker.markActive');
      final normalized = '${e.message} ${e.details ?? ''}'.toLowerCase();
      final userMessage = normalized.contains('unique')
          ? 'No se pudo marcar activa: ya existe una temporada activa.'
          : e.message;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(userMessage)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final seasonsAsync = ref.watch(seasonsListProvider);
    final activeAsync = ref.watch(activeSeasonProvider);

    return AppScaffold(
      title: AppStrings.season,
      body: WatermarkedBody(
        child: profileAsync.when(
          data: (profile) {
            final isSuperAdmin = profile?.isSuperAdmin ?? false;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Temporada: torneos'),
                            const SizedBox(height: 2),
                            activeAsync.when(
                              data: (season) => Text(
                                season == null
                                    ? 'No hay temporada activa'
                                    : 'Activa: ${season.name}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              loading: () =>
                                  const Text('Cargando temporada activa...'),
                              error: (error, stack) => Text('Error: $error'),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: isSuperAdmin
                            ? () => _openCreateSeasonSheet(context, ref)
                            : null,
                        icon: const Icon(Icons.add),
                        label: const Text('Crear temporada'),
                      ),
                    ],
                  ),
                ),
                if (!isSuperAdmin)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                          'Solo super_admin puede crear/activar temporadas.'),
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: seasonsAsync.when(
                    data: (seasons) {
                      if (seasons.isEmpty) {
                        return const EmptyState(
                          title: 'Sin temporadas',
                          message: 'Crea la primera temporada para comenzar.',
                          icon: Icons.calendar_month_outlined,
                        );
                      }

                      final hasActive = seasons.any((s) => s.isActive);

                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (!hasActive)
                            Card(
                              child: ListTile(
                                leading:
                                    const Icon(Icons.warning_amber_outlined),
                                title: const Text('No hay temporada activa'),
                                subtitle: const Text(
                                    'Marca una temporada como activa para operar la app.'),
                              ),
                            ),
                          ...seasons.map(
                            (season) => Card(
                              child: ListTile(
                                title: Text(season.name),
                                subtitle: Text(
                                  '${_fmtDate(season.startsOn)} a ${_fmtDate(season.endsOn)}',
                                ),
                                onTap: () =>
                                    context.push('/temporada/${season.id}'),
                                trailing: Wrap(
                                  spacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (season.isActive)
                                      const Chip(label: Text('ACTIVA')),
                                    OutlinedButton(
                                      onPressed:
                                          isSuperAdmin && !season.isActive
                                              ? () => _markActive(
                                                  context, ref, season.id)
                                              : null,
                                      child: const Text('Marcar activa'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () =>
                        const Loading(message: 'Cargando temporadas...'),
                    error: (error, stack) =>
                        Center(child: Text('Error: $error')),
                  ),
                ),
              ],
            );
          },
          loading: () => const Loading(message: 'Cargando permisos...'),
          error: (error, stack) => Center(child: Text('Error: $error')),
        ),
      ),
    );
  }
}

class _CreateSeasonSheet extends ConsumerStatefulWidget {
  const _CreateSeasonSheet();

  @override
  ConsumerState<_CreateSeasonSheet> createState() => _CreateSeasonSheetState();
}

class _CreateSeasonSheetState extends ConsumerState<_CreateSeasonSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  DateTime _startsOn = DateTime(DateTime.now().year, 1, 1);
  DateTime _endsOn = DateTime(DateTime.now().year, 12, 31);
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startsOn,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _startsOn = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endsOn,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _endsOn = picked);
  }

  Future<void> _save() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;
    if (_endsOn.isBefore(_startsOn)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('La fecha final debe ser mayor o igual a la inicial.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await ref.read(seasonsRepoProvider).createSeason(
            SeasonCreate(
              name: _nameController.text.trim(),
              startsOn: _startsOn,
              endsOn: _endsOn,
            ),
          );

      if (!mounted) return;
      Navigator.of(context).pop();
    } on PostgrestException catch (e) {
      AppLogger.supabaseError(e, scope: 'SeasonPicker.createSeason');
      final normalized = '${e.message} ${e.details ?? ''}'.toLowerCase();
      final userMessage = normalized.contains('unique')
          ? 'No se pudo crear la temporada por una restriccion unica.'
          : e.message;
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(userMessage)));
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
                Text('Crear temporada',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Inicio'),
                  subtitle: Text(_fmtDate(_startsOn)),
                  trailing: TextButton(
                      onPressed: _pickStart, child: const Text('Cambiar')),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fin'),
                  subtitle: Text(_fmtDate(_endsOn)),
                  trailing: TextButton(
                      onPressed: _pickEnd, child: const Text('Cambiar')),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Guardando...' : 'Guardar temporada'),
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

String _fmtDate(DateTime date) => DateTime(date.year, date.month, date.day)
    .toIso8601String()
    .split('T')
    .first;
