import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/game_event.dart';

@Deprecated(
  'Repo legacy no conectado a UI/rutas actuales. TODO(tech-debt): eliminar '
  'GameEventsRepo cuando game_events quede oficialmente deprecado.',
)
class GameEventsRepo {
  GameEventsRepo(this._client);

  final SupabaseClient _client;

  Future<List<GameEvent>> listByGameId(String gameId) async {
    final data = await _client
        .from('game_events')
        .select(
          'id, game_id, player_id, period, side, event_type, yards, notes, created_at, '
          'players(first_name,last_name,jersey_number)',
        )
        .eq('game_id', gameId)
        .order('created_at', ascending: false);

    return (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(GameEvent.fromMap)
        .toList();
  }

  Future<GameEvent> addEvent(GameEvent event) async {
    final created = await _client
        .from('game_events')
        .insert(event.toMap())
        .select(
          'id, game_id, player_id, period, side, event_type, yards, notes, created_at, '
          'players(first_name,last_name,jersey_number)',
        )
        .single();

    return GameEvent.fromMap(created);
  }

  Future<void> deleteEvent(String eventId) async {
    await _client.from('game_events').delete().eq('id', eventId);
  }
}
