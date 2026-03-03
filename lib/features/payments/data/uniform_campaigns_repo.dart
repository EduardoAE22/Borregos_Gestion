import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/uniform_campaign.dart';

class UniformCampaignsRepo {
  UniformCampaignsRepo(this._client);

  final SupabaseClient _client;

  Future<List<UniformCampaign>> listBySeason(String seasonId) async {
    final data = await _client
        .from('uniform_campaigns')
        .select(
          'id, season_id, name, provider, unit_price, deposit_percent, notes, is_active, created_at',
        )
        .eq('season_id', seasonId)
        .order('is_active', ascending: false)
        .order('created_at', ascending: false);

    return (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(UniformCampaign.fromMap)
        .toList();
  }

  Future<UniformCampaign> create({
    required String seasonId,
    required String name,
    String? provider,
    required double unitPrice,
    required double depositPercent,
    String? notes,
    bool isActive = true,
  }) async {
    final data = await _client
        .from('uniform_campaigns')
        .insert({
          'season_id': seasonId,
          'name': name.trim(),
          'provider': (provider ?? '').trim().isEmpty ? null : provider!.trim(),
          'unit_price': unitPrice,
          'deposit_percent': depositPercent,
          'notes': (notes ?? '').trim().isEmpty ? null : notes!.trim(),
          'is_active': isActive,
        })
        .select(
          'id, season_id, name, provider, unit_price, deposit_percent, notes, is_active, created_at',
        )
        .single();

    return UniformCampaign.fromMap(data);
  }

  Future<UniformCampaign> update({
    required String campaignId,
    required Map<String, dynamic> patch,
  }) async {
    final data = await _client
        .from('uniform_campaigns')
        .update(patch)
        .eq('id', campaignId)
        .select(
          'id, season_id, name, provider, unit_price, deposit_percent, notes, is_active, created_at',
        )
        .single();

    return UniformCampaign.fromMap(data);
  }

  Future<void> delete(String campaignId) async {
    await _client.from('uniform_campaigns').delete().eq('id', campaignId);
  }
}
