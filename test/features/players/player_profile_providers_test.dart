import 'package:borregos_gestion/features/auth/providers/auth_providers.dart';
import 'package:borregos_gestion/features/players/providers/player_profile_providers.dart';
import 'package:borregos_gestion/features/seasons/domain/season.dart';
import 'package:borregos_gestion/features/seasons/providers/seasons_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('viewer no intenta consultar jugadas en playerSeasonStatsProvider',
      () async {
    var fetchCalls = 0;

    final container = ProviderContainer(
      overrides: [
        currentProfileProvider.overrideWith(
          (ref) async => const AppProfile(
            id: 'viewer-1',
            fullName: 'Viewer',
            role: 'viewer',
          ),
        ),
        playerPlayRowsFetcherProvider.overrideWithValue(
          (playerId) async {
            fetchCalls += 1;
            return <Map<String, dynamic>>[];
          },
        ),
      ],
    );
    addTearDown(container.dispose);

    final stats = await container.read(playerSeasonStatsProvider('p-1').future);

    expect(fetchCalls, 0);
    expect(stats.passAttempts, 0);
    expect(stats.receptions, 0);
  });

  test('viewer no intenta consultar jugadas en playerGameLogProvider',
      () async {
    var fetchCalls = 0;

    final container = ProviderContainer(
      overrides: [
        currentProfileProvider.overrideWith(
          (ref) async => const AppProfile(
            id: 'viewer-2',
            fullName: 'Viewer',
            role: 'viewer',
          ),
        ),
        playerPlayRowsFetcherProvider.overrideWithValue(
          (playerId) async {
            fetchCalls += 1;
            return <Map<String, dynamic>>[];
          },
        ),
      ],
    );
    addTearDown(container.dispose);

    final rows = await container.read(playerGameLogProvider('p-1').future);

    expect(fetchCalls, 0);
    expect(rows, isEmpty);
  });

  test('matchesActiveSeasonGame aplica regla torneo/global correctamente', () {
    expect(
      matchesActiveSeasonGame(
        {'season_id': 's1', 'roster_season_id': null},
        's1',
      ),
      isTrue,
    );
    expect(
      matchesActiveSeasonGame(
        {'season_id': 's2', 'roster_season_id': 's1'},
        's1',
      ),
      isFalse,
    );
    expect(
      matchesActiveSeasonGame(
        {'season_id': null, 'roster_season_id': 's1'},
        's1',
      ),
      isTrue,
    );
    expect(
      matchesActiveSeasonGame(
        {'season_id': null, 'roster_season_id': 's2'},
        's1',
      ),
      isFalse,
    );
    expect(
      matchesActiveSeasonGame(
        {'season_id': null, 'roster_season_id': null},
        's1',
      ),
      isTrue,
    );
    expect(
      matchesActiveSeasonGame(
        <String, dynamic>{},
        's1',
      ),
      isTrue,
    );
  });

  test(
      'playerSeasonStatsProvider filtra mezcla de temporadas con regla torneo/global',
      () async {
    final activeSeason = Season(
      id: 's1',
      name: 'Temporada 1',
      startsOn: DateTime(2026, 1, 1),
      endsOn: DateTime(2026, 12, 31),
      isActive: true,
    );

    final rows = <Map<String, dynamic>>[
      // torneo activo -> incluir
      {
        'yards': 10,
        'is_target': true,
        'is_completion': true,
        'is_drop': false,
        'is_pass_td': true,
        'is_rush_td': false,
        'is_interception': false,
        'is_pick6': false,
        'is_sack': false,
        'is_tackle_flag': false,
        'is_pass_defended': false,
        'unit': 'ofensiva',
        'qb_player_id': 'p1',
        'receiver_player_id': 'p2',
        'defender_player_id': null,
        'games': {
          'id': 'g1',
          'season_id': 's1',
          'roster_season_id': null,
          'opponent': 'A',
          'game_date': '2026-02-01',
          'game_type': 'torneo',
          'our_score': 0,
          'opp_score': 0,
        },
      },
      // torneo otra temporada -> excluir
      {
        'yards': 20,
        'is_target': true,
        'is_completion': true,
        'is_drop': false,
        'is_pass_td': false,
        'is_rush_td': false,
        'is_interception': false,
        'is_pick6': false,
        'is_sack': false,
        'is_tackle_flag': false,
        'is_pass_defended': false,
        'unit': 'ofensiva',
        'qb_player_id': 'p1',
        'receiver_player_id': null,
        'defender_player_id': null,
        'games': {
          'id': 'g2',
          'season_id': 's2',
          'roster_season_id': null,
          'opponent': 'B',
          'game_date': '2026-02-08',
          'game_type': 'torneo',
          'our_score': 0,
          'opp_score': 0,
        },
      },
      // global con roster activo -> incluir
      {
        'yards': 5,
        'is_target': true,
        'is_completion': false,
        'is_drop': false,
        'is_pass_td': false,
        'is_rush_td': false,
        'is_interception': false,
        'is_pick6': false,
        'is_sack': false,
        'is_tackle_flag': false,
        'is_pass_defended': false,
        'unit': 'ofensiva',
        'qb_player_id': 'p1',
        'receiver_player_id': null,
        'defender_player_id': null,
        'games': {
          'id': 'g3',
          'season_id': null,
          'roster_season_id': 's1',
          'opponent': 'C',
          'game_date': '2026-02-15',
          'game_type': 'amistoso',
          'our_score': 0,
          'opp_score': 0,
        },
      },
      // global con roster distinto -> excluir
      {
        'yards': 7,
        'is_target': true,
        'is_completion': true,
        'is_drop': false,
        'is_pass_td': false,
        'is_rush_td': false,
        'is_interception': false,
        'is_pick6': false,
        'is_sack': false,
        'is_tackle_flag': false,
        'is_pass_defended': false,
        'unit': 'ofensiva',
        'qb_player_id': 'p1',
        'receiver_player_id': null,
        'defender_player_id': null,
        'games': {
          'id': 'g4',
          'season_id': null,
          'roster_season_id': 's3',
          'opponent': 'D',
          'game_date': '2026-02-22',
          'game_type': 'interno',
          'our_score': 0,
          'opp_score': 0,
        },
      },
    ];

    final container = ProviderContainer(
      overrides: [
        currentProfileProvider.overrideWith(
          (ref) async => const AppProfile(
            id: 'coach-1',
            fullName: 'Coach',
            role: 'coach',
          ),
        ),
        activeSeasonProvider.overrideWith((ref) async => activeSeason),
        playerPlayRowsFetcherProvider
            .overrideWithValue((playerId) async => rows),
      ],
    );
    addTearDown(container.dispose);

    final stats = await container.read(playerSeasonStatsProvider('p1').future);
    final gameLog = await container.read(playerGameLogProvider('p1').future);

    expect(stats.passAttempts, 2); // g1 + g3
    expect(stats.passCompletions, 1); // g1
    expect(stats.passYards, 10); // g1
    expect(stats.passTds, 1); // g1
    expect(gameLog.map((e) => e.gameId).toSet(), {'g1', 'g3'});
  });
}
