import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/uniform_campaign.dart';
import '../providers/uniform_campaigns_providers.dart';

class UniformCampaignFormSheet extends ConsumerStatefulWidget {
  const UniformCampaignFormSheet({
    super.key,
    required this.seasonId,
    required this.onSaved,
    this.initialCampaign,
  });

  final String seasonId;
  final VoidCallback onSaved;
  final UniformCampaign? initialCampaign;

  @override
  ConsumerState<UniformCampaignFormSheet> createState() =>
      _UniformCampaignFormSheetState();
}

class _UniformCampaignFormSheetState
    extends ConsumerState<UniformCampaignFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _providerController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _depositPercentController = TextEditingController(text: '50');
  final _notesController = TextEditingController();
  bool _isActive = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCampaign;
    if (initial == null) return;
    _nameController.text = initial.name;
    _providerController.text = initial.provider ?? '';
    _unitPriceController.text =
        initial.unitPrice.toStringAsFixed(initial.unitPrice % 1 == 0 ? 0 : 2);
    _depositPercentController.text = initial.depositPercent.toStringAsFixed(
      initial.depositPercent % 1 == 0 ? 0 : 2,
    );
    _notesController.text = initial.notes ?? '';
    _isActive = initial.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _providerController.dispose();
    _unitPriceController.dispose();
    _depositPercentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double _parseMoney(String value) {
    return double.parse(value.trim().replaceAll(',', '.'));
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    try {
      final repo = ref.read(uniformCampaignsRepoProvider);
      if (widget.initialCampaign == null) {
        await repo.create(
          seasonId: widget.seasonId,
          name: _nameController.text.trim(),
          provider: _providerController.text.trim(),
          unitPrice: _parseMoney(_unitPriceController.text),
          depositPercent: _parseMoney(_depositPercentController.text),
          notes: _notesController.text.trim(),
          isActive: _isActive,
        );
      } else {
        await repo.update(
          campaignId: widget.initialCampaign!.id,
          patch: {
            'name': _nameController.text.trim(),
            'provider': _providerController.text.trim().isEmpty
                ? null
                : _providerController.text.trim(),
            'unit_price': _parseMoney(_unitPriceController.text),
            'deposit_percent': _parseMoney(_depositPercentController.text),
            'notes': _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            'is_active': _isActive,
          },
        );
      }

      if (!mounted) return;
      widget.onSaved();
      Navigator.of(context).pop();
    } on PostgrestException catch (e) {
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
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.initialCampaign == null
                      ? 'Crear uniforme'
                      : 'Editar campana de uniforme',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _providerController,
                  decoration: const InputDecoration(labelText: 'Proveedor'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _unitPriceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Costo unitario'),
                  validator: (value) => double.tryParse(
                              (value ?? '').trim().replaceAll(',', '.')) ==
                          null
                      ? 'Monto invalido'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _depositPercentController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: '% anticipo'),
                  validator: (value) => double.tryParse(
                              (value ?? '').trim().replaceAll(',', '.')) ==
                          null
                      ? 'Porcentaje invalido'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notas'),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isActive,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _isActive = value),
                  title: const Text('Activa'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Guardando...' : 'Guardar campana'),
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
