import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading.dart';
import '../players/domain/player.dart';
import '../seasons/providers/seasons_providers.dart';
import 'domain/uniform_extra.dart';
import 'domain/uniform_line.dart';
import 'providers/uniforms_providers.dart';

class UniformDataQualityPage extends ConsumerStatefulWidget {
  const UniformDataQualityPage({
    super.key,
    this.seasonId,
    this.initialMissing,
    this.numberRequired = false,
  });

  final String? seasonId;
  final String? initialMissing;
  final bool numberRequired;

  @override
  ConsumerState<UniformDataQualityPage> createState() =>
      _UniformDataQualityPageState();
}

class _UniformDataQualityPageState
    extends ConsumerState<UniformDataQualityPage> {
  final _searchController = TextEditingController();
  String _missingFilter = '';
  bool _onlyIncomplete = true;

  @override
  void initState() {
    super.initState();
    _missingFilter = widget.initialMissing ?? '';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seasonAsync = ref.watch(activeSeasonProvider);
    return AppScaffold(
      title: 'Calidad de datos (Uniformes)',
      body: seasonAsync.when(
        data: (activeSeason) {
          final seasonId = widget.seasonId ?? activeSeason?.id;
          if (seasonId == null) {
            return const EmptyState(
              title: 'Sin temporada',
              message: 'Selecciona una temporada activa.',
              icon: Icons.calendar_month_outlined,
            );
          }

          final playersAsync =
              ref.watch(uniformsIncludedPlayersBySeasonProvider(seasonId));
          final extrasAsync =
              ref.watch(uniformsExtrasBySeasonProvider(seasonId));
          if (playersAsync.isLoading || extrasAsync.isLoading) {
            return const Loading(message: 'Calculando faltantes...');
          }

          final players = playersAsync.valueOrNull ?? const <Player>[];
          final extras = extrasAsync.valueOrNull ?? const <UniformExtra>[];
          final lines = [
            ...players.map(UniformLine.fromPlayer),
            ...extras.map(UniformLine.fromExtra),
          ];

          final filtered = lines.where((line) {
            final incomplete = line.missingSize ||
                line.missingGender ||
                (widget.numberRequired && line.missingNumber) ||
                line.missingPhoto;
            if (_onlyIncomplete && !incomplete) return false;
            if (_missingFilter == 'size' && !line.missingSize) return false;
            if (_missingFilter == 'gender' && !line.missingGender) return false;
            if (_missingFilter == 'number' && !line.missingNumber) return false;
            if (_missingFilter == 'photo' && !line.missingPhoto) return false;

            final q = _searchController.text.trim().toLowerCase();
            if (q.isEmpty) return true;
            return line.name.toLowerCase().contains(q) ||
                (line.jerseyNumber?.toString() ?? '').contains(q);
          }).toList()
            ..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Mostrar solo incompletos'),
                      value: _onlyIncomplete,
                      onChanged: (value) =>
                          setState(() => _onlyIncomplete = value),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('Todos'),
                          selected: _missingFilter.isEmpty,
                          onSelected: (_) =>
                              setState(() => _missingFilter = ''),
                        ),
                        FilterChip(
                          label: const Text('Talla'),
                          selected: _missingFilter == 'size',
                          onSelected: (_) =>
                              setState(() => _missingFilter = 'size'),
                        ),
                        FilterChip(
                          label: const Text('Género'),
                          selected: _missingFilter == 'gender',
                          onSelected: (_) =>
                              setState(() => _missingFilter = 'gender'),
                        ),
                        FilterChip(
                          label: const Text('Número'),
                          selected: _missingFilter == 'number',
                          onSelected: (_) =>
                              setState(() => _missingFilter = 'number'),
                        ),
                        FilterChip(
                          label: const Text('Foto'),
                          selected: _missingFilter == 'photo',
                          onSelected: (_) =>
                              setState(() => _missingFilter = 'photo'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Filtro "Número": solo jugadores.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Buscar por nombre o # jersey',
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyState(
                        title: 'Sin resultados',
                        message: 'No hay líneas para los filtros actuales.',
                        icon: Icons.fact_check_outlined,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final line = filtered[index];
                          final missing = <String>[
                            if (line.missingSize) 'Talla',
                            if (line.missingGender) 'Género',
                            if (line.missingNumber) 'Número',
                            if (line.missingPhoto) 'Foto',
                          ];
                          return Card(
                            child: ListTile(
                              title: Text(
                                  '#${line.jerseyNumber ?? '-'} · ${line.name}'),
                              subtitle: Text('Falta: ${missing.join(', ')}'),
                              trailing: line.playerId != null
                                  ? IconButton(
                                      tooltip: 'Editar jugador',
                                      onPressed: () => context.push(
                                          '/players/${line.playerId}/edit'),
                                      icon: const Icon(Icons.edit_outlined),
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Loading(message: 'Cargando temporada...'),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
