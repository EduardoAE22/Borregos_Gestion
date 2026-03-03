import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/game_events_repo.dart';
import '../domain/game_event.dart';

@Deprecated(
  'Provider legacy no usado por rutas/paginas actuales. TODO(tech-debt): '
  'eliminar game_events_providers si no se reactiva ese modulo.',
)
final gameEventsRepoProvider = Provider<GameEventsRepo>((ref) {
  return GameEventsRepo(Supabase.instance.client);
});

@Deprecated(
  'Provider legacy no usado por rutas/paginas actuales. TODO(tech-debt): '
  'eliminar game_events_providers si no se reactiva ese modulo.',
)
final gameEventsByGameProvider =
    FutureProvider.family<List<GameEvent>, String>((ref, gameId) async {
  return ref.read(gameEventsRepoProvider).listByGameId(gameId);
});
