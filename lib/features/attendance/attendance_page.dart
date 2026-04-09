import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading.dart';
import '../payments/domain/payment.dart';
import '../payments/domain/weekly_payments_board.dart';
import '../payments/providers/payments_providers.dart';
import '../players/domain/player.dart';
import '../seasons/providers/seasons_providers.dart';
import 'domain/attendance_entry.dart';
import 'providers/attendance_providers.dart';

class AttendancePage extends ConsumerStatefulWidget {
  const AttendancePage({
    super.key,
    this.initialDate,
  });

  final DateTime? initialDate;

  @override
  ConsumerState<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends ConsumerState<AttendancePage> {
  late DateTime _selectedDate;
  String? _loadedKey;
  final Map<String, bool> _presentByPlayer = <String, bool>{};
  final TextEditingController _searchController = TextEditingController();
  bool _saving = false;
  bool _ensuringSession = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final now = widget.initialDate ?? DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
      _loadedKey = null;
    });
  }

  void _syncAttendanceState(
    String seasonId,
    List<Player> players,
    List<AttendanceEntry> attendance,
  ) {
    final key = '$seasonId|${_selectedDate.toIso8601String()}|${attendance.length}|${players.length}';
    if (_loadedKey == key) return;
    _presentByPlayer
      ..clear()
      ..addEntries(
        players.map((player) => MapEntry(player.id!, false)),
      );
    for (final entry in attendance) {
      _presentByPlayer[entry.playerId] = entry.status == AttendanceStatus.present;
    }
    _loadedKey = key;
  }

  Future<void> _ensureSession(String seasonId) async {
    setState(() => _ensuringSession = true);
    try {
      await ref.read(attendanceRepoProvider).ensureTrainingSession(
            seasonId,
            _selectedDate,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesión lista para esta fecha.')),
      );
    } finally {
      if (mounted) {
        setState(() => _ensuringSession = false);
      }
    }
  }

  Future<void> _saveAttendance(String seasonId) async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(attendanceRepoProvider);
      final sessionId = await repo.ensureTrainingSession(seasonId, _selectedDate);
      final entries = _presentByPlayer.entries.toList();
      for (final entry in entries) {
        await repo.upsertAttendance(
          sessionId: sessionId,
          playerId: entry.key,
          status: entry.value ? AttendanceStatus.present : AttendanceStatus.absent,
        );
      }

      final weekStart = getWeekStartMonday(_selectedDate);
      final weekEnd = getWeekEndSunday(_selectedDate);
      ref.invalidate(
        attendanceBySeasonAndDateProvider(
          (seasonId: seasonId, date: _selectedDate),
        ),
      );
      ref.invalidate(
        attendanceForActiveSeasonWeekProvider(
          (weekStart: weekStart, weekEnd: weekEnd),
        ),
      );
      ref.invalidate(
        weeklyPaymentsByCategoryProvider(
          (weekStart: weekStart, category: PaymentCategory.training),
        ),
      );
      ref.invalidate(weeklyPaymentStatusByPlayerProvider(weekStart));
      ref.invalidate(weeklyDebtCountsByPlayerProvider(weekStart));
      ref.invalidate(weeklyPaymentsDashboardProvider(weekStart));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Asistencia guardada.')),
      );
      context.go('/payments');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<Player> _filterPlayers(List<Player> players) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return players;

    return players.where((player) {
      final firstName = player.firstName.toLowerCase();
      final lastName = player.lastName.toLowerCase();
      final fullName = player.fullName.toLowerCase();
      final nickname = (player.jerseyName ?? '').trim().toLowerCase();
      final jerseyNumber = player.jerseyNumber.toString().toLowerCase();

      return firstName.contains(query) ||
          lastName.contains(query) ||
          fullName.contains(query) ||
          nickname.contains(query) ||
          jerseyNumber.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final seasonAsync = ref.watch(activeSeasonProvider);
    final playersAsync = ref.watch(activeSeasonActivePlayersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Asistencia'),
        leading: IconButton(
          onPressed: () => context.go('/payments'),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          TextButton(
            onPressed: () => context.go('/payments'),
            child: const Text('Volver a pagos'),
          ),
        ],
      ),
      body: seasonAsync.when(
        data: (season) {
          if (season == null) {
            return const EmptyState(
              title: 'Sin temporada activa',
              message: 'Selecciona una temporada activa para capturar asistencia.',
              icon: Icons.event_busy_outlined,
            );
          }

          final attendanceAsync = ref.watch(
            attendanceBySeasonAndDateProvider(
              (seasonId: season.id, date: _selectedDate),
            ),
          );

          return playersAsync.when(
            data: (players) {
              final activePlayers = players.where((player) => player.isActive).toList();
              final attendance = attendanceAsync.valueOrNull ?? const <AttendanceEntry>[];
              final filteredPlayers = _filterPlayers(activePlayers);
              _syncAttendanceState(season.id, activePlayers, attendance);

              return FutureBuilder<bool>(
                future: ref
                    .read(attendanceRepoProvider)
                    .hasTrainingSessionOnDate(season.id, _selectedDate),
                builder: (context, snapshot) {
                  final hasSession = snapshot.data ?? false;
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Fecha: ${_selectedDate.toIso8601String().split('T').first}',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _pickDate,
                                  icon: const Icon(Icons.calendar_today_outlined),
                                  label: const Text('Elegir fecha'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Chip(
                                  label: Text(
                                    hasSession
                                        ? 'Sesión del día: lista'
                                        : 'Sesión del día: pendiente',
                                  ),
                                ),
                                FilledButton.icon(
                                  onPressed: _ensuringSession
                                      ? null
                                      : () => _ensureSession(season.id),
                                  icon: const Icon(Icons.event_available_outlined),
                                  label: const Text('Crear o usar sesión del día'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _searchController,
                              onChanged: (value) => setState(() => _searchQuery = value),
                              decoration: InputDecoration(
                                hintText: 'Buscar por nombre, apodo o jersey',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _searchQuery.isEmpty
                                    ? null
                                    : IconButton(
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                        icon: const Icon(Icons.clear),
                                      ),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: activePlayers.isEmpty
                            ? const EmptyState(
                                title: 'Sin jugadores activos',
                                message: 'No hay jugadores activos para esta temporada.',
                                icon: Icons.groups_outlined,
                              )
                            : filteredPlayers.isEmpty
                                ? const EmptyState(
                                    title: 'Sin resultados',
                                    message:
                                        'No hay jugadores que coincidan con la búsqueda.',
                                    icon: Icons.search_off_outlined,
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                    itemCount: filteredPlayers.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final player = filteredPlayers[index];
                                      final nickname = (player.jerseyName ?? '').trim();
                                      return Card(
                                        child: SwitchListTile(
                                          value: _presentByPlayer[player.id!] ?? false,
                                          onChanged: (value) => setState(
                                            () => _presentByPlayer[player.id!] = value,
                                          ),
                                          title: Text(player.fullName),
                                          subtitle: Text(
                                            nickname.isNotEmpty
                                                ? 'Apodo: $nickname • #${player.jerseyNumber}'
                                                : '#${player.jerseyNumber}',
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _saving ? null : () => _saveAttendance(season.id),
                              icon: const Icon(Icons.save_outlined),
                              label: Text(_saving ? 'Guardando...' : 'Guardar asistencia'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
            loading: () => const Loading(message: 'Cargando jugadores...'),
            error: (error, stack) => Center(child: Text('Error: $error')),
          );
        },
        loading: () => const Loading(message: 'Cargando temporada...'),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
