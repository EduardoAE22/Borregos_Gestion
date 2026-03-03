import 'package:flutter/material.dart';

import '../domain/player_metric.dart';

class MetricFormSheet extends StatefulWidget {
  const MetricFormSheet({
    super.key,
    required this.playerId,
    required this.onSubmit,
  });

  final String playerId;
  final Future<void> Function(PlayerMetric metric) onSubmit;

  @override
  State<MetricFormSheet> createState() => _MetricFormSheetState();
}

class _MetricFormSheetState extends State<MetricFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _fortyController = TextEditingController();
  final _tenController = TextEditingController();
  final _shuttleController = TextEditingController();
  final _verticalController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _measuredOn = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _fortyController.dispose();
    _tenController.dispose();
    _shuttleController.dispose();
    _verticalController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _measuredOn,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() => _measuredOn = picked);
    }
  }

  double? _toDouble(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return null;
    return double.tryParse(clean);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    try {
      final metric = PlayerMetric(
        playerId: widget.playerId,
        measuredOn: _measuredOn,
        fortyYdSeconds: _toDouble(_fortyController.text),
        tenYdSplit: _toDouble(_tenController.text),
        shuttle5105: _toDouble(_shuttleController.text),
        verticalJumpCm: _toDouble(_verticalController.text),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      await widget.onSubmit(metric);
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Agregar medicion',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fecha de medicion'),
                  subtitle:
                      Text(_measuredOn.toIso8601String().split('T').first),
                  trailing: TextButton(
                    onPressed: _pickDate,
                    child: const Text('Cambiar'),
                  ),
                ),
                TextFormField(
                  controller: _fortyController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: '40 yd (segundos)'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _tenController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: '10 yd split'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _shuttleController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Shuttle 5-10-5'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _verticalController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Salto vertical (cm)'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notas'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Guardando...' : 'Guardar medicion'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
