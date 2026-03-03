import 'package:supabase_flutter/supabase_flutter.dart';

import '../../players/domain/player.dart';
import '../domain/uniform_extra.dart';

class UniformsRepo {
  UniformsRepo(this._client);

  final SupabaseClient _client;
  static const _extraColumns =
      'id, season_id, name, quantity, jersey_number, jersey_size, uniform_gender, notes, created_at';

  Future<List<Player>> listActivePlayersForSeason(String seasonId) async {
    final data = await _client
        .from('players')
        .select()
        .eq('season_id', seasonId)
        .eq('is_active', true)
        .order('jersey_number', ascending: true);

    return (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Player.fromMap)
        .toList();
  }

  Future<List<UniformExtra>> listExtrasBySeason(String seasonId) async {
    final data = await _client
        .from('uniform_order_extras')
        .select(_extraColumns)
        .eq('season_id', seasonId)
        .order('created_at', ascending: false);

    return (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(UniformExtra.fromMap)
        .toList();
  }

  Future<UniformExtra> upsertExtra(UniformExtra extra) async {
    if (extra.id == null) {
      final created = await _client
          .from('uniform_order_extras')
          .insert(extra.toMap())
          .select(_extraColumns)
          .single();
      return UniformExtra.fromMap(created);
    }

    final updated = await _client
        .from('uniform_order_extras')
        .update(extra.toMap())
        .eq('id', extra.id!)
        .select(_extraColumns)
        .single();
    return UniformExtra.fromMap(updated);
  }

  Future<void> deleteExtra(String id) async {
    await _client.from('uniform_order_extras').delete().eq('id', id);
  }
}
