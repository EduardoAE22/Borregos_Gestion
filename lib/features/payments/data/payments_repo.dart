import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/payment.dart';
import '../domain/weekly_payments_board.dart';
import '../domain/weekly_summary.dart';
import '../../settings/data/settings_repo.dart';

class WeeklyConceptNotConfiguredException implements Exception {
  const WeeklyConceptNotConfiguredException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UnauthorizedException implements Exception {
  const UnauthorizedException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ReceiptFileTypeNotAllowedException implements Exception {
  const ReceiptFileTypeNotAllowedException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PaymentsRepo {
  PaymentsRepo(this._client);

  final SupabaseClient _client;
  static const _receiptBucket = 'payment_receipts';
  static const _paymentSelect =
      'id, season_id, player_id, concept_id, uniform_campaign_id, amount, paid_amount, status, week_start, week_end, payment_method, reference, paid_at, notes, receipt_url, created_at, created_by, '
      'players(first_name,last_name,jersey_name,jersey_number), '
      'payment_concepts(name,category,amount)';

  Future<List<PaymentConcept>> listConceptsActive() async {
    final data = await _client
        .from('payment_concepts')
        .select('id, name, amount, category')
        .eq('is_active', true)
        .order('name', ascending: true);

    return (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(PaymentConcept.fromMap)
        .toList();
  }

  Future<String?> getPaymentConceptWeekly() async {
    final data = await _client
        .from('payment_concepts')
        .select('id, name, amount, category')
        .eq('is_active', true)
        .or('name.ilike.Semana,name.ilike.Semanal')
        .order('name', ascending: true);

    final concepts = (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(PaymentConcept.fromMap)
        .where((concept) => isWeeklyPaymentConceptName(concept.name))
        .toList();

    if (concepts.isEmpty) return null;
    return concepts.first.id;
  }

  Future<String?> getPaymentConceptUniform() async {
    final data = await _client
        .from('payment_concepts')
        .select('id, name, amount, category')
        .eq('is_active', true)
        .ilike('name', 'Uniforme')
        .order('name', ascending: true);

    final concepts = (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(PaymentConcept.fromMap)
        .where((concept) => isUniformPaymentConceptName(concept.name))
        .toList();

    if (concepts.isEmpty) return null;
    return concepts.first.id;
  }

  Future<List<PaymentRow>> listPaymentsBySeason(
    UUID seasonId, {
    DateTime? from,
    DateTime? to,
  }) async {
    var query = _client
        .from('payments')
        .select(_paymentSelect)
        .eq('season_id', seasonId);

    if (from != null) {
      query = query.gte('paid_at', _asDate(from));
    }
    if (to != null) {
      query = query.lt('paid_at', _asDate(to.add(const Duration(days: 1))));
    }

    final data = await query.order('paid_at', ascending: false);

    return (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(PaymentRow.fromMap)
        .toList();
  }

  Future<List<PaymentRow>> listPaymentsByPlayer(
      UUID seasonId, UUID playerId) async {
    final data = await _client
        .from('payments')
        .select(_paymentSelect)
        .eq('season_id', seasonId)
        .eq('player_id', playerId)
        .order('paid_at', ascending: false);

    return (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(PaymentRow.fromMap)
        .toList();
  }

  Future<void> addPayment({
    required UUID seasonId,
    required UUID playerId,
    required UUID conceptId,
    required double amount,
    required DateTime paidAt,
    DateTime? weekStart,
    DateTime? weekEnd,
    double? paidAmount,
    String status = 'paid',
    String? paymentMethod,
    String? reference,
    String? notes,
    String? receiptUrl,
    UUID? uniformCampaignId,
  }) async {
    final userId = await _requirePaymentsWriteRole();

    await _client.from('payments').insert({
      'season_id': seasonId,
      'player_id': playerId,
      'concept_id': conceptId,
      'amount': amount,
      'paid_amount': paidAmount ?? amount,
      'status': status,
      'week_start': weekStart != null ? _asDate(weekStart) : null,
      'week_end': weekEnd != null ? _asDate(weekEnd) : null,
      'payment_method': paymentMethod,
      'reference': reference,
      'paid_at': paidAt.toIso8601String(),
      'notes': notes,
      'receipt_url': receiptUrl,
      'uniform_campaign_id': uniformCampaignId,
      'created_by': userId,
    });
  }

  Future<void> updatePayment({
    required UUID paymentId,
    required UUID conceptId,
    required double amount,
    required DateTime paidAt,
    DateTime? weekStart,
    DateTime? weekEnd,
    double? paidAmount,
    String status = 'paid',
    String? paymentMethod,
    String? reference,
    String? notes,
    UUID? uniformCampaignId,
  }) async {
    await _requirePaymentsWriteRole();

    await _client.from('payments').update({
      'concept_id': conceptId,
      'amount': amount,
      'paid_amount': paidAmount ?? amount,
      'status': status,
      'week_start': weekStart != null ? _asDate(weekStart) : null,
      'week_end': weekEnd != null ? _asDate(weekEnd) : null,
      'payment_method': paymentMethod,
      'reference': reference,
      'paid_at': paidAt.toIso8601String(),
      'notes': notes,
      'uniform_campaign_id': uniformCampaignId,
    }).eq('id', paymentId);
  }

  Future<void> deletePayment(UUID paymentId) async {
    await _requirePaymentsWriteRole();
    await _client.from('payments').delete().eq('id', paymentId);
  }

  Future<String> uploadReceiptForPayment({
    required UUID seasonId,
    required UUID paymentId,
    required String filename,
    required Uint8List bytes,
    String? oldReceiptPath,
  }) async {
    await _requirePaymentsWriteRole();

    const fileTypeError =
        'Tipo de archivo no permitido. Usa JPG, PNG, WEBP o PDF.';
    final lower = filename.trim().toLowerCase();
    final dot = lower.lastIndexOf('.');
    if (lower.isEmpty || dot <= 0 || dot + 1 >= lower.length) {
      throw const FormatException(fileTypeError);
    }

    final rawExt = lower.substring(dot + 1).trim();
    if (rawExt.isEmpty) {
      throw const FormatException(fileTypeError);
    }

    final ext = switch (rawExt) {
      'jpeg' => 'jpg',
      'jpg' || 'png' || 'webp' || 'pdf' => rawExt,
      _ => throw const FormatException(fileTypeError),
    };
    final contentType = switch (ext) {
      'jpg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      _ => 'application/octet-stream',
    };
    final objectPath =
        'receipts/season_$seasonId/payment_$paymentId/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _client.storage.from(_receiptBucket).uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: contentType,
          ),
        );

    await _client
        .from('payments')
        .update({'receipt_url': objectPath}).eq('id', paymentId);

    final oldPath = _extractReceiptPath(oldReceiptPath);
    if (oldPath != null && oldPath.isNotEmpty && oldPath != objectPath) {
      try {
        await _client.storage.from(_receiptBucket).remove([oldPath]);
      } catch (_) {
        // Best effort cleanup, ignore failures.
      }
    }

    return objectPath;
  }

  Future<String> createReceiptSignedUrl(
    String receiptPath, {
    int expiresInSeconds = 60 * 60 * 24 * 7,
  }) async {
    final path = _extractReceiptPath(receiptPath);
    if (path == null || path.isEmpty) {
      throw const StorageException('Invalid receipt path');
    }
    return _client.storage
        .from(_receiptBucket)
        .createSignedUrl(path, expiresInSeconds);
  }

  Future<List<PaymentPlayerOption>> listSeasonPlayers(UUID seasonId) async {
    final data = await _client
        .from('players')
        .select('id, jersey_number, first_name, last_name, jersey_name')
        .eq('season_id', seasonId)
        .eq('is_active', true)
        .order('jersey_number', ascending: true);

    return (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(PaymentPlayerOption.fromMap)
        .toList();
  }

  Future<List<PaymentRow>> listPaymentsForWeek({
    required UUID seasonId,
    required DateTime weekStart,
  }) async {
    final normalizedWeekStart = _asDate(mondayOfWeek(weekStart));
    final weekAfter = _asDate(
      mondayOfWeek(weekStart).add(const Duration(days: 7)),
    );

    final data = await _client
        .from('payments')
        .select(_paymentSelect)
        .eq('season_id', seasonId)
        .gte('week_start', normalizedWeekStart)
        .lt('week_start', weekAfter)
        .order('paid_at', ascending: false);

    return (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(PaymentRow.fromMap)
        .toList();
  }

  Future<List<PaymentRow>> listPaymentsForWeekByCategory({
    required UUID seasonId,
    required DateTime weekStart,
    required DateTime weekEnd,
    required PaymentCategory category,
  }) async {
    final payments = await listPaymentsForWeek(
      seasonId: seasonId,
      weekStart: weekStart,
    );
    return payments
        .where((payment) => payment.paymentCategory == category)
        .toList();
  }

  Future<List<PaymentRow>> listPaymentsForRange({
    required UUID seasonId,
    required DateTime fromWeekStart,
    required DateTime toWeekStart,
  }) async {
    final data = await _client
        .from('payments')
        .select(_paymentSelect)
        .eq('season_id', seasonId)
        .gte('week_start', _asDate(mondayOfWeek(fromWeekStart)))
        .lte('week_start', _asDate(mondayOfWeek(toWeekStart)))
        .order('week_start', ascending: true)
        .order('paid_at', ascending: false);

    return (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(PaymentRow.fromMap)
        .toList();
  }

  Future<List<PaymentRow>> listPaymentsByCategory({
    required UUID seasonId,
    required PaymentCategory category,
  }) async {
    final payments = await listPaymentsBySeason(seasonId);
    return payments
        .where((payment) => payment.paymentCategory == category)
        .toList();
  }

  Future<List<PaymentRow>> listUniformPaymentsForCampaign({
    required UUID seasonId,
    required UUID campaignId,
    List<UUID>? playerIds,
  }) async {
    var query = _client
        .from('payments')
        .select(_paymentSelect)
        .eq('season_id', seasonId)
        .eq('uniform_campaign_id', campaignId);

    if (playerIds != null && playerIds.isNotEmpty) {
      query = query.inFilter('player_id', playerIds);
    }

    final data = await query.order('paid_at', ascending: false);
    return (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(PaymentRow.fromMap)
        .where((payment) => payment.paymentCategory == PaymentCategory.uniform)
        .toList();
  }

  Future<WeeklySummary> weeklySummary(UUID seasonId, DateTime weekStart) async {
    final normalizedStart =
        DateTime(weekStart.year, weekStart.month, weekStart.day);
    final normalizedEnd = normalizedStart.add(const Duration(days: 6));
    final settingsRepo = SettingsRepo(_client);
    final semanaConceptId = await settingsRepo.getWeeklyPaymentConceptId();

    final activeConcept = await _client
        .from('payment_concepts')
        .select('id')
        .eq('id', semanaConceptId)
        .eq('is_active', true)
        .maybeSingle();
    if (activeConcept == null) {
      final conceptById = await _client
          .from('payment_concepts')
          .select('id')
          .eq('id', semanaConceptId)
          .maybeSingle();

      if (conceptById == null) {
        throw const WeeklyConceptNotConfiguredException(
          'El concepto semanal configurado no existe en payment_concepts.',
        );
      }

      throw const WeeklyConceptNotConfiguredException(
        'El concepto semanal configurado existe pero esta inactivo.',
      );
    }

    final playersData = await _client
        .from('players')
        .select('id, first_name, last_name, jersey_number')
        .eq('season_id', seasonId)
        .eq('is_active', true)
        .order('jersey_number', ascending: true);
    final players = (playersData as List<dynamic>).cast<Map<String, dynamic>>();

    final byPlayerAmount = <UUID, double>{};
    for (final player in players) {
      byPlayerAmount[player['id'] as UUID] = 0;
    }

    final weeklyFeeAmount = await settingsRepo.getWeeklyFeeAmount();
    final conceptAmountData = await _client
        .from('payment_concepts')
        .select('amount')
        .eq('id', semanaConceptId)
        .maybeSingle();
    final conceptAmount = conceptAmountData == null
        ? 0.0
        : _parseNumeric(conceptAmountData['amount']);
    final expectedAmount = weeklyFeeAmount > 0
        ? weeklyFeeAmount
        : (conceptAmount > 0 ? conceptAmount : fallbackWeeklyFeeAmount);

    final paymentsData = await _client
        .from('payments')
        .select('player_id, paid_amount, status')
        .eq('season_id', seasonId)
        .eq('concept_id', semanaConceptId)
        .gte('paid_at', normalizedStart.toIso8601String())
        .lt('paid_at',
            normalizedEnd.add(const Duration(days: 1)).toIso8601String());
    final rows = (paymentsData as List<dynamic>).cast<Map<String, dynamic>>();

    for (final row in rows) {
      final playerId = row['player_id'] as UUID;
      if (!byPlayerAmount.containsKey(playerId)) continue;
      final normalizedStatus = (row['status'] as String? ?? '').trim();
      if (normalizedStatus.toLowerCase() != 'paid' &&
          normalizedStatus.toLowerCase() != 'partial') {
        continue;
      }
      final amount = _parseNumeric(row['paid_amount']);
      if (amount <= 0) continue;
      byPlayerAmount[playerId] = (byPlayerAmount[playerId] ?? 0) + amount;
    }

    var totalPaid = 0.0;
    var paidPlayers = 0;
    var partialPlayers = 0;
    final byPlayer = players.map((player) {
      final playerId = player['id'] as UUID;
      final firstName = player['first_name'] as String? ?? '';
      final lastName = player['last_name'] as String? ?? '';
      final jersey = player['jersey_number'];
      final amountPaidThisWeek = byPlayerAmount[playerId] ?? 0;
      final state = resolvePaymentState(
        amountPaid: amountPaidThisWeek,
        amountExpected: expectedAmount,
      );
      final paidThisWeek = state == PaymentState.paid;
      final pending = state == PaymentState.pending;

      if (state == PaymentState.paid) paidPlayers += 1;
      if (state == PaymentState.partial) partialPlayers += 1;
      totalPaid += amountPaidThisWeek;

      return PlayerWeeklySummary(
        playerId: playerId,
        playerName: '#${jersey ?? '-'} ${'$firstName $lastName'.trim()}',
        paymentState: switch (state) {
          PaymentState.pending => 'pending',
          PaymentState.partial => 'partial',
          PaymentState.paid => 'paid',
        },
        requiredAmount: expectedAmount,
        paidThisWeek: paidThisWeek,
        amountPaidThisWeek: amountPaidThisWeek,
        pending: pending,
      );
    }).toList()
      ..sort((a, b) {
        if (a.pending != b.pending) {
          return a.pending ? -1 : 1;
        }
        return a.playerName.compareTo(b.playerName);
      });

    final totalPlayers = players.length;
    return WeeklySummary(
      totalPaid: totalPaid,
      totalPlayers: totalPlayers,
      paidPlayers: paidPlayers,
      partialPlayers: partialPlayers,
      pendingPlayers: totalPlayers - paidPlayers - partialPlayers,
      byPlayer: byPlayer,
    );
  }

  static DateTime mondayOfWeek(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    final shift = local.weekday - DateTime.monday;
    return local.subtract(Duration(days: shift < 0 ? 6 : shift));
  }

  static String _asDate(DateTime date) =>
      DateTime(date.year, date.month, date.day)
          .toIso8601String()
          .split('T')
          .first;

  static double _parseNumeric(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  String? _extractReceiptPath(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final raw = value.trim();
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        (!raw.startsWith('http://') && !raw.startsWith('https://'))) {
      return raw;
    }

    final segments = uri.pathSegments;
    final bucketIndex = segments.indexOf(_receiptBucket);
    if (bucketIndex == -1 || bucketIndex + 1 >= segments.length) return null;
    return segments.sublist(bucketIndex + 1).join('/');
  }

  Future<String> _requirePaymentsWriteRole() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const UnauthorizedException(
          'Debes iniciar sesion para realizar esta accion.');
    }

    final profile = await _client
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .maybeSingle();
    final role = (profile?['role'] as String?)?.trim().toLowerCase();
    if (role != 'super_admin' && role != 'coach') {
      throw const UnauthorizedException(
        'No tienes permisos para gestionar pagos. Requiere rol super_admin o coach.',
      );
    }

    return userId;
  }
}
