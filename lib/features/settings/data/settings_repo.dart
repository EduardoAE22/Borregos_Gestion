import 'package:supabase_flutter/supabase_flutter.dart';

class InvalidWeeklyConceptSettingException implements Exception {
  const InvalidWeeklyConceptSettingException(this.message);

  final String message;

  @override
  String toString() => message;
}

double parseWeeklyFeeAmount(String? rawValue) {
  final normalized = (rawValue ?? '').trim().replaceAll(',', '.');
  if (normalized.isEmpty) return 0;
  return double.tryParse(normalized) ?? 0;
}

class SettingsRepo {
  SettingsRepo(this._client);

  final SupabaseClient _client;
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  Future<String?> getStringByKey(String key) async {
    final data = await _client
        .from('app_settings')
        .select('value')
        .eq('key', key)
        .maybeSingle();
    if (data == null) return null;

    final raw = data['value'];
    if (raw == null) return null;

    final value = raw.toString().trim();
    return value.isEmpty ? null : value;
  }

  Future<String> getWeeklyPaymentConceptId() async {
    final value = await getStringByKey('weekly_payment_concept_id');
    if (value == null || value.trim().isEmpty) {
      throw const InvalidWeeklyConceptSettingException(
        'El ajuste weekly_payment_concept_id no existe o esta vacio en app_settings.',
      );
    }

    if (!_uuidRegex.hasMatch(value)) {
      throw const InvalidWeeklyConceptSettingException(
        'El ajuste weekly_payment_concept_id no es un UUID valido en app_settings.',
      );
    }

    return value;
  }

  Future<double> getWeeklyFeeAmount() async {
    final value = await getStringByKey('weekly_fee_amount');
    return parseWeeklyFeeAmount(value);
  }
}
