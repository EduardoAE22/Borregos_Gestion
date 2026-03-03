import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/player_profile_requirements.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading.dart';
import '../seasons/providers/seasons_providers.dart';
import 'domain/player.dart';
import 'domain/player_completeness.dart';
import 'providers/players_providers.dart';

class PlayerDataQualityPage extends ConsumerStatefulWidget {
  const PlayerDataQualityPage({
    super.key,
    this.missingFieldFilter,
  });

  final String? missingFieldFilter;

  @override
  ConsumerState<PlayerDataQualityPage> createState() =>
      _PlayerDataQualityPageState();
}

class _PlayerDataQualityPageState extends ConsumerState<PlayerDataQualityPage> {
  final _searchController = TextEditingController();
  bool _onlyIncomplete = true;
  String? _selectedMissingKey;

  @override
  void initState() {
    super.initState();
    _selectedMissingKey = widget.missingFieldFilter?.trim().isEmpty ?? true
        ? null
        : PlayerCompletenessHelper.normalizeFieldKey(
            widget.missingFieldFilter!.trim());
    if (_selectedMissingKey != null) {
      _onlyIncomplete = true;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seasonAsync = ref.watch(activeSeasonProvider);
    final playersAsync = ref.watch(playersByActiveSeasonProvider);

    return AppScaffold(
      title: 'Calidad de datos',
      selectedNavIndex: 0,
      body: seasonAsync.when(
        data: (season) {
          if (season == null) {
            return const EmptyState(
              title: 'Sin temporada activa',
              message:
                  'Selecciona una temporada activa para evaluar calidad de datos.',
              icon: Icons.calendar_month_outlined,
            );
          }

          return playersAsync.when(
            data: (players) {
              final rows = _buildRows(players);
              final total = players.length;
              final complete =
                  rows.where((row) => row.missingLabels.isEmpty).length;
              final incomplete = total - complete;
              final chipMissingCounts = _buildMissingChipCounts(rows);

              final filtered = rows.where((row) {
                if (_onlyIncomplete && row.missingLabels.isEmpty) {
                  return false;
                }
                if (_selectedMissingKey != null &&
                    !row.filterMissingKeys.contains(_selectedMissingKey)) {
                  return false;
                }

                final query = _searchController.text.trim().toLowerCase();
                if (query.isEmpty) return true;
                final fullName =
                    '${row.player.firstName} ${row.player.lastName}'
                        .toLowerCase();
                final jersey = row.player.jerseyNumber.toString();
                return fullName.contains(query) || jersey.contains(query);
              }).toList();

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Temporada activa: ${season.name}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _MiniStat(label: 'Total', value: '$total'),
                            _MiniStat(label: 'Completos', value: '$complete'),
                            _MiniStat(
                                label: 'Incompletos', value: '$incomplete'),
                            _MiniStat(
                                label: 'Mostrando',
                                value: '${filtered.length}'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Todos'),
                              selected: !_onlyIncomplete &&
                                  _selectedMissingKey == null,
                              selectedColor:
                                  Theme.of(context).colorScheme.secondary,
                              side: BorderSide(
                                  color:
                                      Theme.of(context).colorScheme.secondary),
                              onSelected: (_) {
                                setState(() {
                                  _selectedMissingKey = null;
                                  _onlyIncomplete = false;
                                });
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Solo incompletos'),
                              selected: _onlyIncomplete,
                              selectedColor:
                                  Theme.of(context).colorScheme.secondary,
                              side: BorderSide(
                                  color:
                                      Theme.of(context).colorScheme.secondary),
                              onSelected: (_) {
                                setState(() {
                                  _onlyIncomplete = !_onlyIncomplete;
                                });
                              },
                            ),
                            ...chipMissingCounts.map(
                              (entry) {
                                final selected =
                                    _selectedMissingKey == entry.key;
                                return ChoiceChip(
                                  label: Text(
                                    '${PlayerProfileRequirements.labelFor(entry.key)} (${entry.value})',
                                  ),
                                  selected: selected,
                                  selectedColor:
                                      Theme.of(context).colorScheme.secondary,
                                  side: BorderSide(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondary),
                                  onSelected: (_) {
                                    setState(() {
                                      _selectedMissingKey =
                                          selected ? null : entry.key;
                                      _onlyIncomplete = true;
                                    });
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _selectedMissingKey == null
                              ? 'Filtro: Todos'
                              : 'Filtro: ${PlayerProfileRequirements.labelFor(_selectedMissingKey!)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),
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
                            message: 'No hay jugadores para el filtro actual.',
                            icon: Icons.fact_check_outlined,
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final row = filtered[index];
                              final missingCount = row.missingLabels.length;
                              final isComplete = missingCount == 0;

                              return Card(
                                child: ListTile(
                                  onTap: isComplete
                                      ? null
                                      : () => _openPlayerSheet(context, row),
                                  title: Text(
                                    '#${row.player.jerseyNumber} ${row.player.firstName} ${row.player.lastName}',
                                  ),
                                  subtitle: Text(
                                    isComplete
                                        ? 'Falta: Sin faltantes'
                                        : 'Falta: ${row.missingLabels.join(', ')}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Chip(
                                        label: Text(isComplete
                                            ? 'Completo'
                                            : 'Incompleto'),
                                      ),
                                      if (!isComplete && row.player.id != null)
                                        IconButton(
                                          tooltip: 'Editar jugador',
                                          onPressed: () => context.push(
                                              '/players/${row.player.id}/edit'),
                                          icon: const Icon(Icons.edit_outlined),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
            loading: () =>
                const Loading(message: 'Evaluando calidad de datos...'),
            error: (error, stack) => Center(child: Text('Error: $error')),
          );
        },
        loading: () => const Loading(message: 'Buscando temporada activa...'),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  List<_PlayerQualityRow> _buildRows(List<Player> players) {
    final rows = players.map((player) {
      return _PlayerQualityRow(
        player: player,
        missingKeys: PlayerCompletenessHelper.missingFieldKeysForPlayer(player),
        missingLabels:
            PlayerCompletenessHelper.missingFieldLabelsForPlayer(player),
        chipMissingKeys:
            PlayerCompletenessHelper.missingChipFieldKeysForPlayer(player),
      );
    }).toList()
      ..sort((a, b) {
        final aIncomplete = a.missingLabels.isNotEmpty;
        final bIncomplete = b.missingLabels.isNotEmpty;
        if (aIncomplete != bIncomplete) return aIncomplete ? -1 : 1;

        final byMissing =
            b.missingLabels.length.compareTo(a.missingLabels.length);
        if (byMissing != 0) return byMissing;

        return a.player.jerseyNumber.compareTo(b.player.jerseyNumber);
      });
    return rows;
  }

  List<MapEntry<String, int>> _buildMissingChipCounts(
      List<_PlayerQualityRow> rows) {
    final counts = <String, int>{};
    for (final row in rows) {
      for (final key in row.filterMissingKeys) {
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }

    const priority = <String>[
      'foto',
      'talla',
      'genero',
      'posicion',
      'contacto_emergencia',
      'edad',
      'telefono',
    ];

    final entries = counts.entries.where((entry) => entry.value > 0).toList()
      ..sort((a, b) {
        final aIndex = priority.indexOf(a.key);
        final bIndex = priority.indexOf(b.key);
        final aPriority = aIndex == -1 ? 999 : aIndex;
        final bPriority = bIndex == -1 ? 999 : bIndex;
        if (aPriority != bPriority) return aPriority.compareTo(bPriority);
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return PlayerProfileRequirements.labelFor(a.key)
            .compareTo(PlayerProfileRequirements.labelFor(b.key));
      });

    return entries;
  }

  void _openPlayerSheet(BuildContext context, _PlayerQualityRow row) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${row.player.jerseyNumber} ${row.player.firstName} ${row.player.lastName}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                ...row.missingLabels.map((label) => Text('• $label')),
                const SizedBox(height: 14),
                if (row.player.id != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        this.context.push('/players/${row.player.id}/edit');
                      },
                      child: const Text('Editar jugador'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: Theme.of(context).textTheme.bodySmall),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _PlayerQualityRow {
  const _PlayerQualityRow({
    required this.player,
    required this.missingKeys,
    required this.missingLabels,
    required this.chipMissingKeys,
  });

  final Player player;
  final List<String> missingKeys;
  final List<String> missingLabels;
  final List<String> chipMissingKeys;

  List<String> get filterMissingKeys =>
      <String>{...missingKeys, ...chipMissingKeys}.toList();
}
