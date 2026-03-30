import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/logger.dart';
import '../../auth/providers/auth_providers.dart';
import '../../settings/providers/settings_providers.dart';
import '../domain/payment.dart';
import '../providers/payments_providers.dart';

class PaymentFormSheet extends ConsumerStatefulWidget {
  const PaymentFormSheet({
    super.key,
    required this.seasonId,
    required this.onSaved,
    this.initialPayment,
    this.initialPlayerId,
    this.initialConceptId,
    this.initialWeekStart,
    this.initialWeekEnd,
    this.initialUniformCampaignId,
  });

  final UUID seasonId;
  final VoidCallback onSaved;
  final PaymentRow? initialPayment;
  final UUID? initialPlayerId;
  final UUID? initialConceptId;
  final DateTime? initialWeekStart;
  final DateTime? initialWeekEnd;
  final UUID? initialUniformCampaignId;

  @override
  ConsumerState<PaymentFormSheet> createState() => _PaymentFormSheetState();
}

class _PaymentFormSheetState extends ConsumerState<PaymentFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _referenceController = TextEditingController();

  UUID? _playerId;
  UUID? _conceptId;
  DateTime _paidAt = DateTime.now();
  String? _paymentMethod;
  bool _saving = false;
  bool _didInitializeConcept = false;
  bool _weeklyConceptMissingNotified = false;
  bool _uniformConceptMissingNotified = false;
  bool _amountEditedManually = false;
  bool _applyingSuggestedAmount = false;

  @override
  void initState() {
    super.initState();
    _playerId = widget.initialPayment?.playerId ?? widget.initialPlayerId;
    _conceptId = widget.initialPayment?.conceptId ?? widget.initialConceptId;
    _paidAt = widget.initialPayment?.paidAt ?? DateTime.now();
    _paymentMethod = widget.initialPayment?.paymentMethod;
    _amountController.text = widget.initialPayment != null
        ? widget.initialPayment!.amount.toStringAsFixed(
            widget.initialPayment!.amount.truncateToDouble() ==
                    widget.initialPayment!.amount
                ? 0
                : 2,
          )
        : '';
    _notesController.text = widget.initialPayment?.notes ?? '';
    _referenceController.text = widget.initialPayment?.reference ?? '';
    _amountController.addListener(_handleAmountChanged);
  }

  @override
  void dispose() {
    _amountController.removeListener(_handleAmountChanged);
    _amountController.dispose();
    _notesController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  void _handleAmountChanged() {
    if (_applyingSuggestedAmount) return;
    _amountEditedManually = true;
  }

  double _parseMoney(String input) {
    final clean = input.trim().replaceAll(',', '.');
    return double.parse(clean);
  }

  double? _tryParseMoney(String input) {
    final clean = input.trim().replaceAll(',', '.');
    if (clean.isEmpty) return null;
    return double.tryParse(clean);
  }

  void _applySuggestedAmount(double amount) {
    if (amount <= 0 || _amountEditedManually) return;

    final currentText = _amountController.text.trim();
    final currentAmount = _tryParseMoney(currentText) ?? 0;
    if (currentText.isNotEmpty && currentAmount > 0) return;

    _applyingSuggestedAmount = true;
    _amountController.text =
        amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2);
    _amountController.selection = TextSelection.fromPosition(
      TextPosition(offset: _amountController.text.length),
    );
    _applyingSuggestedAmount = false;
  }

  Future<void> _pickPaidAt() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paidAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _paidAt = DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _pickPlayer(List<PaymentPlayerOption> players) async {
    final selected = await showModalBottomSheet<UUID>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        var query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = players.where((p) {
              final q = query.trim().toLowerCase();
              if (q.isEmpty) return true;
              return p.label.toLowerCase().contains(q);
            }).toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Buscar jugador',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) => setModalState(() => query = value),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final player = filtered[index];
                          return ListTile(
                            title: Text(player.label),
                            onTap: () => Navigator.of(context).pop(player.id),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || selected == null) return;
    setState(() => _playerId = selected);
  }

  Future<void> _save() async {
    final profile = await ref.read(currentProfileProvider.future);
    if (!(profile?.canWritePayments ?? false)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Solo super_admin o coach pueden registrar pagos.')),
      );
      return;
    }

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || _playerId == null || _conceptId == null) return;

    final enteredAmount = _parseMoney(_amountController.text);
    final selectedStatus =
        (widget.initialPayment?.status ?? 'paid').trim().toLowerCase();
    if (selectedStatus == 'paid' && enteredAmount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pago inválido: el monto pagado debe ser mayor a 0'),
        ),
      );
      return;
    }

    final normalizedPayment = normalizePaymentDraft(
      amount: enteredAmount,
      paidAmount: enteredAmount,
      status: selectedStatus,
    );

    setState(() => _saving = true);

    try {
      if (widget.initialPayment != null) {
        await ref.read(paymentsRepoProvider).updatePayment(
              paymentId: widget.initialPayment!.id,
              conceptId: _conceptId!,
              amount: normalizedPayment.amount,
              paidAt: _paidAt,
              weekStart:
                  widget.initialWeekStart ?? widget.initialPayment!.weekStart,
              weekEnd: widget.initialWeekEnd ?? widget.initialPayment!.weekEnd,
              paidAmount: normalizedPayment.paidAmount,
              status: normalizedPayment.status,
              paymentMethod: _paymentMethod,
              reference: _referenceController.text.trim().isEmpty
                  ? null
                  : _referenceController.text.trim(),
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
              uniformCampaignId: widget.initialUniformCampaignId ??
                  widget.initialPayment!.uniformCampaignId,
            );
      } else {
        await ref.read(paymentsRepoProvider).addPayment(
              seasonId: widget.seasonId,
              playerId: _playerId!,
              conceptId: _conceptId!,
              amount: normalizedPayment.amount,
              paidAt: _paidAt,
              weekStart: widget.initialWeekStart,
              weekEnd: widget.initialWeekEnd,
              paidAmount: normalizedPayment.paidAmount,
              status: normalizedPayment.status,
              paymentMethod: _paymentMethod,
              reference: _referenceController.text.trim().isEmpty
                  ? null
                  : _referenceController.text.trim(),
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
              uniformCampaignId: widget.initialUniformCampaignId,
            );
      }

      if (!mounted) return;
      widget.onSaved();
      Navigator.of(context).pop();
    } on PostgrestException catch (e) {
      AppLogger.supabaseError(e, scope: 'Payments.save');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playersAsync =
        widget.initialUniformCampaignId != null
            ? ref.watch(seasonPlayersForUniformPaymentProvider(widget.seasonId))
            : ref.watch(seasonPlayersForPaymentProvider(widget.seasonId));
    final conceptsAsync = ref.watch(paymentConceptsProvider);
    final weeklyConceptAsync = widget.initialWeekStart != null
        ? ref.watch(weeklyPaymentConceptProvider)
        : const AsyncData<String?>(null);
    final uniformConceptAsync = widget.initialUniformCampaignId != null
        ? ref.watch(uniformPaymentConceptProvider)
        : const AsyncData<String?>(null);
    final weeklyFeeAmountAsync = widget.initialWeekStart != null
        ? ref.watch(weeklyFeeAmountProvider)
        : const AsyncData<double>(0);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    widget.initialPayment != null
                        ? 'Editar pago'
                        : 'Registrar pago',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                playersAsync.when(
                  data: (players) {
                    final availablePlayers = _availablePlayers(players);
                    final selectedPlayer =
                        availablePlayers.cast<PaymentPlayerOption?>().firstWhere(
                              (p) => p?.id == _playerId,
                              orElse: () => null,
                            );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Jugador',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 6),
                        OutlinedButton.icon(
                          onPressed:
                              _saving
                                  ? null
                                  : () => _pickPlayer(availablePlayers),
                          icon: const Icon(Icons.search),
                          label: Text(
                              selectedPlayer?.label ?? 'Seleccionar jugador'),
                        ),
                        if (widget.initialUniformCampaignId != null &&
                            widget.initialPayment != null &&
                            selectedPlayer != null &&
                            !_playerStillEligible(players))
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'El jugador de este pago histórico ya no está incluido en uniforme, pero se conserva temporalmente para poder editar este registro.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        if (_playerId == null)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              'Selecciona jugador',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                      ],
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  ),
                  error: (error, stack) =>
                      Text('Error cargando jugadores: $error'),
                ),
                const SizedBox(height: 10),
                conceptsAsync.when(
                  data: (concepts) {
                    if (widget.initialWeekStart != null) {
                      return weeklyConceptAsync.when(
                        data: (weeklyConceptId) {
                          if (!_didInitializeConcept && concepts.isNotEmpty) {
                            _didInitializeConcept = true;
                            _conceptId = weeklyConceptId ?? concepts.first.id;

                            if (weeklyConceptId == null &&
                                !_weeklyConceptMissingNotified) {
                              _weeklyConceptMissingNotified = true;
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "No existe concepto 'Semana'. Elige uno.",
                                    ),
                                  ),
                                );
                              });
                            }
                          }

                          return _ConceptField(
                            concepts: concepts,
                            value: _conceptId,
                            onChanged: (value) =>
                                setState(() => _conceptId = value),
                            showWeeklyHint: weeklyConceptId == null,
                          );
                        },
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(),
                        ),
                        error: (error, stack) => Text(
                          'Error cargando concepto semanal: $error',
                        ),
                      );
                    }

                    if (widget.initialUniformCampaignId != null) {
                      return uniformConceptAsync.when(
                        data: (uniformConceptId) {
                          if (!_didInitializeConcept && concepts.isNotEmpty) {
                            _didInitializeConcept = true;
                            _conceptId = widget.initialPayment?.conceptId ??
                                widget.initialConceptId ??
                                uniformConceptId ??
                                concepts.first.id;

                            if (uniformConceptId == null &&
                                !_uniformConceptMissingNotified) {
                              _uniformConceptMissingNotified = true;
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "No existe concepto 'Uniforme'. Elige uno.",
                                    ),
                                  ),
                                );
                              });
                            }
                          }

                          return _ConceptField(
                            concepts: concepts,
                            value: _conceptId,
                            onChanged: (value) =>
                                setState(() => _conceptId = value),
                            hintText: uniformConceptId == null
                                ? "No existe concepto 'Uniforme'. Elige uno."
                                : null,
                          );
                        },
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(),
                        ),
                        error: (error, stack) => Text(
                          'Error cargando concepto de uniforme: $error',
                        ),
                      );
                    }

                    if (!_didInitializeConcept && concepts.isNotEmpty) {
                      _didInitializeConcept = true;
                      _conceptId = widget.initialPayment?.conceptId ??
                          widget.initialConceptId ??
                          concepts.first.id;
                    }

                    return _ConceptField(
                      concepts: concepts,
                      value: _conceptId,
                      onChanged: (value) => setState(() => _conceptId = value),
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  ),
                  error: (error, stack) =>
                      Text('Error cargando conceptos: $error'),
                ),
                const SizedBox(height: 10),
                Builder(
                  builder: (context) {
                    final concepts =
                        conceptsAsync.valueOrNull ?? const <PaymentConcept>[];
                    final weeklyConceptId = weeklyConceptAsync.valueOrNull;
                    final uniformConceptId = uniformConceptAsync.valueOrNull;
                    final weeklyFeeAmount =
                        weeklyFeeAmountAsync.valueOrNull ?? 0;
                    final selectedConcept =
                        concepts.cast<PaymentConcept?>().firstWhere(
                              (concept) => concept?.id == _conceptId,
                              orElse: () => null,
                            );
                    final isWeeklyConcept = (weeklyConceptId != null &&
                            _conceptId == weeklyConceptId) ||
                        isWeeklyPaymentConceptName(selectedConcept?.name);
                    final isUniformConcept = (uniformConceptId != null &&
                            _conceptId == uniformConceptId) ||
                        isUniformPaymentConceptName(selectedConcept?.name);

                    final suggestedAmount = selectedConcept?.amount ??
                        (isWeeklyConcept ? weeklyFeeAmount : 0);
                    if (isWeeklyConcept ||
                        isUniformConcept ||
                        suggestedAmount > 0) {
                      _applySuggestedAmount(suggestedAmount);
                    }

                    return const SizedBox.shrink();
                  },
                ),
                if (widget.initialWeekStart != null &&
                    widget.initialWeekEnd != null) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Semana'),
                    subtitle: Text(
                      '${AppFormatters.date(widget.initialWeekStart!)} - ${AppFormatters.date(widget.initialWeekEnd!)}',
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fecha de pago'),
                  subtitle: Text(AppFormatters.date(_paidAt)),
                  trailing: TextButton(
                    onPressed: _saving ? null : _pickPaidAt,
                    child: const Text('Cambiar'),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Monto'),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) return 'Requerido';
                    if (double.tryParse(value!.trim().replaceAll(',', '.')) ==
                        null) {
                      return 'Monto invalido';
                    }
                    return null;
                  },
                ),
                Builder(
                  builder: (context) {
                    final concepts =
                        conceptsAsync.valueOrNull ?? const <PaymentConcept>[];
                    final weeklyConceptId = weeklyConceptAsync.valueOrNull;
                    final uniformConceptId = uniformConceptAsync.valueOrNull;
                    final weeklyFeeAmount =
                        weeklyFeeAmountAsync.valueOrNull ?? 0;
                    final selectedConcept =
                        concepts.cast<PaymentConcept?>().firstWhere(
                              (concept) => concept?.id == _conceptId,
                              orElse: () => null,
                            );
                    final isWeeklyConcept = (weeklyConceptId != null &&
                            _conceptId == weeklyConceptId) ||
                        isWeeklyPaymentConceptName(selectedConcept?.name);
                    final isUniformConcept = (uniformConceptId != null &&
                            _conceptId == uniformConceptId) ||
                        isUniformPaymentConceptName(selectedConcept?.name);

                    if (widget.initialWeekStart != null && isWeeklyConcept) {
                      final suggestedAmount =
                          selectedConcept?.amount ?? weeklyFeeAmount;
                      final text = suggestedAmount > 0
                          ? 'Monto sugerido semanal: ${AppFormatters.money(suggestedAmount)}'
                          : 'Configura weekly_fee_amount en Ajustes';
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          text,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      );
                    }

                    if (widget.initialUniformCampaignId == null ||
                        !isUniformConcept) {
                      return const SizedBox.shrink();
                    }

                    final suggestedAmount = selectedConcept?.amount ?? 0;
                    final text = suggestedAmount > 0
                        ? 'Monto sugerido uniforme: ${AppFormatters.money(suggestedAmount)}'
                        : null;
                    if (text == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        text,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notas'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _paymentMethod,
                  decoration:
                      const InputDecoration(labelText: 'Metodo de pago'),
                  items: const [
                    DropdownMenuItem(
                      value: 'efectivo',
                      child: Text('Efectivo'),
                    ),
                    DropdownMenuItem(
                      value: 'transferencia',
                      child: Text('Transferencia'),
                    ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _paymentMethod = value),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _referenceController,
                  decoration: const InputDecoration(labelText: 'Referencia'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Guardando...' : 'Guardar pago'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<PaymentPlayerOption> _availablePlayers(List<PaymentPlayerOption> players) {
    if (widget.initialUniformCampaignId == null ||
        widget.initialPayment == null ||
        _playerStillEligible(players)) {
      return players;
    }

    final payment = widget.initialPayment!;
    final fallbackName = (payment.playerJerseyName ?? '').trim();
    final labelName = fallbackName.isNotEmpty
        ? fallbackName
        : (payment.playerName ?? '').replaceFirst(
            RegExp(r'^#-?\d+\s*'),
            '',
          ).trim();

    return [
      ...players,
      PaymentPlayerOption(
        id: payment.playerId,
        jerseyNumber: payment.playerJerseyNumber ?? 0,
        firstName: labelName.isEmpty ? 'Jugador' : labelName,
        lastName: '',
        jerseyName: labelName.isEmpty ? 'Histórico' : labelName,
      ),
    ];
  }

  bool _playerStillEligible(List<PaymentPlayerOption> players) {
    return players.any((player) => player.id == _playerId);
  }
}

class _ConceptField extends StatelessWidget {
  const _ConceptField({
    required this.concepts,
    required this.value,
    required this.onChanged,
    this.showWeeklyHint = false,
    this.hintText,
  });

  final List<PaymentConcept> concepts;
  final UUID? value;
  final ValueChanged<UUID?> onChanged;
  final bool showWeeklyHint;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<UUID>(
          initialValue: value,
          decoration: const InputDecoration(labelText: 'Concepto'),
          items: concepts
              .map(
                (c) => DropdownMenuItem(
                  value: c.id,
                  child: Text(c.name),
                ),
              )
              .toList(),
          onChanged: onChanged,
          validator: (selected) =>
              selected == null ? 'Selecciona concepto' : null,
        ),
        if (showWeeklyHint || hintText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              hintText ?? "No existe concepto 'Semana'. Elige uno.",
              style: const TextStyle(color: Colors.orange),
            ),
          ),
      ],
    );
  }
}
