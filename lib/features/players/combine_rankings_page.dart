import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../core/utils/formatters.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/background_watermark.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading.dart';
import '../seasons/providers/seasons_providers.dart';
import 'domain/combine.dart';
import 'providers/combine_providers.dart';

class CombineRankingsPage extends ConsumerStatefulWidget {
  const CombineRankingsPage({super.key});

  @override
  ConsumerState<CombineRankingsPage> createState() =>
      _CombineRankingsPageState();
}

enum _CombineRankingMode { porPrueba, indiceAtletico }

class _CombineRankingsPageState extends ConsumerState<CombineRankingsPage> {
  String? _selectedSessionId;
  String? _selectedTestId;
  _CombineRankingMode _mode = _CombineRankingMode.porPrueba;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seasonAsync = ref.watch(activeSeasonProvider);
    final sessionsAsync = ref.watch(combineSessionsByActiveSeasonProvider);
    final testsAsync = ref.watch(combineTestsProvider);

    return AppScaffold(
      title: 'Rankings Combine',
      selectedNavIndex: 0,
      body: WatermarkedBody(
        child: seasonAsync.when(
          data: (season) {
            if (season == null) {
              return const EmptyState(
                title: 'Sin temporada activa',
                message:
                    'Selecciona una temporada para ver rankings de Combine.',
                icon: Icons.calendar_month_outlined,
              );
            }
            if (sessionsAsync.isLoading || testsAsync.isLoading) {
              return const Loading(message: 'Cargando combine...');
            }

            final sessions =
                sessionsAsync.valueOrNull ?? const <CombineSession>[];
            final tests = testsAsync.valueOrNull ?? const <CombineTest>[];
            if (sessions.isEmpty) {
              return const EmptyState(
                title: 'Sin sesiones de Combine',
                message: 'Crea una sesión desde el perfil del jugador.',
                icon: Icons.fitness_center_outlined,
              );
            }
            if (tests.isEmpty) {
              return const EmptyState(
                title: 'Sin pruebas activas',
                message:
                    'No hay pruebas de combine activas para mostrar ranking.',
                icon: Icons.list_alt_outlined,
              );
            }

            _selectedSessionId ??= sessions.first.id;
            _selectedTestId ??= tests.first.id;

            final selectedSession = sessions.firstWhere(
              (session) => session.id == _selectedSessionId,
              orElse: () => sessions.first,
            );
            final selectedTest = tests.firstWhere(
              (test) => test.id == _selectedTestId,
              orElse: () => tests.first,
            );
            final query = _searchQuery.trim().toLowerCase();

            List<CombineRankingRow> filteredByTest = const [];
            List<CombineAthleticRankRow> filteredAthletic = const [];
            Object? rankingsError;

            if (_mode == _CombineRankingMode.porPrueba) {
              final rankingsAsync = ref.watch(
                combineRankingsProvider(
                  (
                    sessionId: selectedSession.id,
                    testId: selectedTest.id,
                  ),
                ),
              );
              if (rankingsAsync.isLoading) {
                return const Loading(message: 'Cargando ranking...');
              }
              if (rankingsAsync.hasError) {
                rankingsError = rankingsAsync.error;
              } else {
                final sorted = sortCombineRankings(
                  rows:
                      rankingsAsync.valueOrNull ?? const <CombineRankingRow>[],
                  test: selectedTest,
                );
                filteredByTest = sorted.where((row) {
                  if (query.isEmpty) return true;
                  final haystack = <String>[
                    row.jerseyNumber?.toString() ?? '',
                    row.nombre,
                    row.nombreMostrado,
                  ].map((value) => value.toLowerCase());
                  return haystack.any((value) => value.contains(query));
                }).toList();
              }
            } else {
              final athleticAsync = ref.watch(
                combineAthleticIndexProvider(selectedSession.id),
              );
              if (athleticAsync.isLoading) {
                return const Loading(message: 'Calculando índice atlético...');
              }
              if (athleticAsync.hasError) {
                rankingsError = athleticAsync.error;
              } else {
                filteredAthletic = (athleticAsync.valueOrNull ??
                        const <CombineAthleticRankRow>[])
                    .where((row) {
                  if (query.isEmpty) return true;
                  final haystack = <String>[
                    row.jerseyNumber?.toString() ?? '',
                    row.nombre,
                    row.nombreMostrado,
                  ].map((value) => value.toLowerCase());
                  return haystack.any((value) => value.contains(query));
                }).toList();
              }
            }

            if (rankingsError != null) {
              return Center(
                child: Text('Error cargando ranking: $rankingsError'),
              );
            }

            final isByTest = _mode == _CombineRankingMode.porPrueba;
            final hasResults = isByTest
                ? filteredByTest.isNotEmpty
                : filteredAthletic.isNotEmpty;
            final topRows = isByTest
                ? filteredByTest.take(3).toList()
                : filteredAthletic.take(3).toList();

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Temporada: ${season.name}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        SegmentedButton<_CombineRankingMode>(
                          segments: const [
                            ButtonSegment(
                              value: _CombineRankingMode.porPrueba,
                              label: Text('Por prueba'),
                              icon: Icon(Icons.leaderboard_outlined),
                            ),
                            ButtonSegment(
                              value: _CombineRankingMode.indiceAtletico,
                              label: Text('Índice atlético'),
                              icon: Icon(Icons.insights_outlined),
                            ),
                          ],
                          selected: <_CombineRankingMode>{_mode},
                          onSelectionChanged: (selection) {
                            setState(() => _mode = selection.first);
                          },
                        ),
                        const SizedBox(height: 10),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 780;
                            if (compact) {
                              return Column(
                                children: [
                                  DropdownButtonFormField<String>(
                                    initialValue: selectedSession.id,
                                    decoration: const InputDecoration(
                                        labelText: 'Sesión'),
                                    items: sessions
                                        .map(
                                          (session) => DropdownMenuItem(
                                            value: session.id,
                                            child: Text(
                                              '${session.nombre} • ${AppFormatters.date(session.fecha)}',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(
                                          () => _selectedSessionId = value);
                                    },
                                  ),
                                  if (isByTest) ...[
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      initialValue: selectedTest.id,
                                      decoration: const InputDecoration(
                                          labelText: 'Prueba'),
                                      items: tests
                                          .map(
                                            (test) => DropdownMenuItem(
                                              value: test.id,
                                              child: Text(test.nombre),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setState(() => _selectedTestId = value);
                                      },
                                    ),
                                  ],
                                ],
                              );
                            }

                            if (!isByTest) {
                              return DropdownButtonFormField<String>(
                                initialValue: selectedSession.id,
                                decoration:
                                    const InputDecoration(labelText: 'Sesión'),
                                items: sessions
                                    .map(
                                      (session) => DropdownMenuItem(
                                        value: session.id,
                                        child: Text(
                                          '${session.nombre} • ${AppFormatters.date(session.fecha)}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() => _selectedSessionId = value);
                                },
                              );
                            }

                            return Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: selectedSession.id,
                                    decoration: const InputDecoration(
                                        labelText: 'Sesión'),
                                    items: sessions
                                        .map(
                                          (session) => DropdownMenuItem(
                                            value: session.id,
                                            child: Text(
                                              '${session.nombre} • ${AppFormatters.date(session.fecha)}',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(
                                          () => _selectedSessionId = value);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: selectedTest.id,
                                    decoration: const InputDecoration(
                                        labelText: 'Prueba'),
                                    items: tests
                                        .map(
                                          (test) => DropdownMenuItem(
                                            value: test.id,
                                            child: Text(test.nombre),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(() => _selectedTestId = value);
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            labelText: 'Buscar (apodo, nombre, apellido, #)',
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: topRows.map((row) {
                            if (row is CombineAthleticRankRow) {
                              return Chip(
                                label: Text(
                                  '#${row.jerseyNumber ?? '-'} ${row.nombreMostrado}: ${row.athleticIndex.toStringAsFixed(1)}',
                                ),
                              );
                            }
                            final testRow = row as CombineRankingRow;
                            return Chip(
                              label: Text(
                                '#${testRow.jerseyNumber ?? '-'} ${testRow.nombreMostrado}: ${testRow.valor} ${testRow.unidad}',
                              ),
                            );
                          }).toList(),
                        ),
                        if (!isByTest && filteredAthletic.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () => _showBalancedTeamsSheet(
                              context: context,
                              players: filteredAthletic,
                            ),
                            icon: const Icon(Icons.groups_2_outlined),
                            label: const Text('Generar 2 equipos'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (!hasResults)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      title: 'Sin resultados',
                      message: 'No hay registros para los filtros actuales.',
                      icon: Icons.leaderboard_outlined,
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      MediaQuery.of(context).padding.bottom +
                          kBottomNavigationBarHeight +
                          16,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (isByTest) {
                            final row = filteredByTest[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Text('${index + 1}'),
                                ),
                                title: Text(
                                  '#${row.jerseyNumber ?? '-'} ${row.nombreMostrado}',
                                ),
                                subtitle: Text(row.nombreMostrado != row.nombre
                                    ? row.nombre
                                    : selectedTest.nombre),
                                trailing: Text(
                                  '${row.valor} ${row.unidad}',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                            );
                          }
                          final row = filteredAthletic[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text('${index + 1}'),
                              ),
                              title: Text(
                                '#${row.jerseyNumber ?? '-'} ${row.nombreMostrado}',
                              ),
                              subtitle: Text(
                                'Pruebas: ${row.capturedCount}/${row.totalTests}',
                              ),
                              trailing: Text(
                                row.athleticIndex.toStringAsFixed(1),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          );
                        },
                        childCount: isByTest
                            ? filteredByTest.length
                            : filteredAthletic.length,
                      ),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Loading(message: 'Cargando temporada...'),
          error: (error, _) => Center(child: Text('Error: $error')),
        ),
      ),
    );
  }

  Future<void> _showBalancedTeamsSheet({
    required BuildContext context,
    required List<CombineAthleticRankRow> players,
  }) async {
    var seed = DateTime.now().microsecondsSinceEpoch & 0x7fffffff;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final teams = buildBalancedTeamsSnake(players: players, seed: seed);
            final summaryStyle = Theme.of(context).textTheme.titleSmall;
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  MediaQuery.of(context).padding.bottom + 16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Equipos balanceados',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Total A: ${teams.teamATotal.toStringAsFixed(1)}  ·  Total B: ${teams.teamBTotal.toStringAsFixed(1)}',
                        style: summaryStyle,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Diferencia: ${teams.difference.toStringAsFixed(1)}',
                        style: summaryStyle,
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 720;
                          if (compact) {
                            return Column(
                              children: [
                                _TeamCard(
                                  title:
                                      'Equipo A (${teams.teamATotal.toStringAsFixed(1)})',
                                  rows: teams.teamA,
                                ),
                                const SizedBox(height: 8),
                                _TeamCard(
                                  title:
                                      'Equipo B (${teams.teamBTotal.toStringAsFixed(1)})',
                                  rows: teams.teamB,
                                ),
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _TeamCard(
                                  title:
                                      'Equipo A (${teams.teamATotal.toStringAsFixed(1)})',
                                  rows: teams.teamA,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _TeamCard(
                                  title:
                                      'Equipo B (${teams.teamBTotal.toStringAsFixed(1)})',
                                  rows: teams.teamB,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              setModalState(() {
                                seed = DateTime.now().microsecondsSinceEpoch &
                                    0x7fffffff;
                              });
                            },
                            icon: const Icon(Icons.casino_outlined),
                            label: const Text('Re-generar'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final text =
                                  buildBalancedTeamsWhatsappText(teams);
                              await Clipboard.setData(
                                ClipboardData(text: text),
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Texto copiado. Pégalo en WhatsApp.',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy_all_outlined),
                            label: const Text('Copiar a WhatsApp'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cerrar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({
    required this.title,
    required this.rows,
  });

  final String title;
  final List<CombineAthleticRankRow> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              const Text('Sin jugadores')
            else
              ...rows.map(
                (row) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '#${row.jerseyNumber ?? '-'} ${row.nombreMostrado} · ${row.athleticIndex.toStringAsFixed(1)}',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
