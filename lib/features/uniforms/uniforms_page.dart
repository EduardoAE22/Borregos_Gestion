import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/ui/app_strings.dart';
import '../../core/utils/excel_delivery.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/background_watermark.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading.dart';
import '../auth/providers/auth_providers.dart';
import '../players/domain/player.dart';
import '../seasons/domain/season.dart';
import '../seasons/providers/seasons_providers.dart';
import 'data/uniforms_exporter.dart';
import 'domain/uniform_extra.dart';
import 'domain/uniform_line.dart';
import 'domain/uniform_order_row.dart';
import 'providers/uniforms_providers.dart';

class UniformsPage extends ConsumerStatefulWidget {
  const UniformsPage({super.key});

  @override
  ConsumerState<UniformsPage> createState() => _UniformsPageState();
}

class _UniformsPageState extends ConsumerState<UniformsPage> {
  static const List<String> _jerseySizes = <String>[
    'XS',
    'S',
    'M',
    'L',
    'XL',
    '2XL',
    '3XL',
    '2',
    '4',
    '6',
    '8',
    '10',
    '12',
    '14',
    '16',
  ];
  static const List<String> _genders = <String>['H', 'M', 'Niña', 'Niño'];
  String? _selectedSeasonId;
  bool _numberRequired = false;

  @override
  Widget build(BuildContext context) {
    final seasonsAsync = ref.watch(seasonsListProvider);
    final activeSeasonAsync = ref.watch(activeSeasonProvider);
    final profileAsync = ref.watch(currentProfileProvider);

    return AppScaffold(
      title: AppStrings.uniforms,
      body: WatermarkedBody(
        child: seasonsAsync.when(
          data: (seasons) {
            final media = MediaQuery.of(context);
            final viewPadding = media.padding;
            final isCompact = media.size.width < 600;
            final activeSeason = activeSeasonAsync.valueOrNull;
            final seasonId = _selectedSeasonId ?? activeSeason?.id;
            final season = _seasonById(seasons, seasonId);
            if (seasonId == null || season == null) {
              return const EmptyState(
                title: 'Sin temporada disponible',
                message: 'No se encontró una temporada para generar el pedido.',
                icon: Icons.checkroom_outlined,
              );
            }

            final playersAsync =
                ref.watch(uniformsActivePlayersBySeasonProvider(seasonId));
            final extrasAsync =
                ref.watch(uniformsExtrasBySeasonProvider(seasonId));

            return profileAsync.when(
              data: (profile) {
                final canWrite = profile?.canWriteGeneral ?? false;
                if (playersAsync.isLoading || extrasAsync.isLoading) {
                  return const Loading(message: 'Cargando módulo Uniformes...');
                }

                final players = playersAsync.valueOrNull ?? const <Player>[];
                final extras =
                    extrasAsync.valueOrNull ?? const <UniformExtra>[];
                final lines = _buildOrderLines(players, extras);
                final orderRows = buildUniformOrderRows(lines);

                final totalJerseys = orderRows.length;
                final missingSize =
                    lines.where((line) => line.missingSize).length;
                final missingGender =
                    lines.where((line) => line.missingGender).length;
                final missingNumber =
                    lines.where((line) => line.missingNumber).length;

                return DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                SizedBox(
                                  width:
                                      isCompact ? media.size.width - 32 : 320,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: season.id,
                                    decoration: const InputDecoration(
                                        labelText: 'Temporada'),
                                    items: seasons
                                        .map(
                                          (s) => DropdownMenuItem<String>(
                                            value: s.id,
                                            child: Text(s.name),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(() => _selectedSeasonId = value);
                                    },
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      context.push('/uniformes/requisitos'),
                                  icon: const Icon(Icons.info_outline),
                                  label: const Text('Requisitos'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Chip(
                                    label: Text(
                                        'Total líneas: ${orderRows.length}')),
                                Chip(
                                    label:
                                        Text('Total jerseys: $totalJerseys')),
                                Chip(label: Text('Faltan talla: $missingSize')),
                                Chip(
                                    label:
                                        Text('Falta género: $missingGender')),
                                Chip(
                                    label:
                                        Text('Falta número: $missingNumber')),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                  'Número obligatorio (solo jugadores)'),
                              value: _numberRequired,
                              onChanged: (value) =>
                                  setState(() => _numberRequired = value),
                            ),
                            Wrap(
                              spacing: 8,
                              children: [
                                if (missingSize +
                                        missingGender +
                                        missingNumber >
                                    0)
                                  TextButton.icon(
                                    onPressed: () =>
                                        _showMissingDialog(context, lines),
                                    icon: const Icon(
                                        Icons.warning_amber_outlined),
                                    label: const Text('Ver faltantes'),
                                  ),
                                TextButton.icon(
                                  onPressed: () => context.push(
                                    '/uniformes/calidad?season=$seasonId&missing=&numberRequired=${_numberRequired ? '1' : '0'}',
                                  ),
                                  icon: const Icon(Icons.fact_check_outlined),
                                  label: const Text('Calidad de datos'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Card(
                              child: ExpansionTile(
                                title: const Text('Requisitos del proveedor'),
                                leading: const Icon(Icons.rule_folder_outlined),
                                childrenPadding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                expandedCrossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                      'Formato obligatorio: No. | Nombre | Número # | Talla | Género'),
                                  SizedBox(height: 6),
                                  Text('No. = consecutivo por fila (1..N)'),
                                  SizedBox(height: 6),
                                  Text('Tallas adultos: XS,S,M,L,XL,2XL,3XL'),
                                  SizedBox(height: 6),
                                  Text('Tallas niños: 2,4,6,8,10,12,14,16'),
                                  SizedBox(height: 6),
                                  Text('Género: H, M, Niña, Niño'),
                                  SizedBox(height: 6),
                                  Text(
                                      'No nos hacemos responsables por errores en tallas'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            const TabBar(
                              tabs: [
                                Tab(text: 'Pedido'),
                                Tab(text: 'Extras'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _OrderTab(
                              rows: orderRows,
                              isWeb: kIsWeb,
                              bottomInset: viewPadding.bottom + 12,
                              onExport: () => _exportOrder(
                                context: context,
                                season: season,
                                lines: lines,
                                numberRequired: _numberRequired,
                              ),
                              onShare: () => _shareOrder(
                                context: context,
                                season: season,
                                lines: lines,
                              ),
                              onExportSizes: () => _exportSizesSummary(
                                context: context,
                                season: season,
                                lines: lines,
                              ),
                            ),
                            _ExtrasTab(
                              extras: extras,
                              canWrite: canWrite,
                              bottomInset: viewPadding.bottom + 12,
                              onAdd: () => _openExtraDialog(context, seasonId,
                                  canWrite: canWrite),
                              onEdit: (extra) => _openExtraDialog(
                                  context, seasonId,
                                  initial: extra, canWrite: canWrite),
                              onDelete: (extra) => _deleteExtra(context, extra,
                                  canWrite: canWrite),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Loading(message: 'Cargando permisos...'),
              error: (error, stack) => Center(child: Text('Error: $error')),
            );
          },
          loading: () => const Loading(message: 'Cargando temporadas...'),
          error: (error, stack) => Center(child: Text('Error: $error')),
        ),
      ),
    );
  }

  Season? _seasonById(List<Season> seasons, String? seasonId) {
    if (seasonId == null) return null;
    for (final season in seasons) {
      if (season.id == seasonId) return season;
    }
    return null;
  }

  List<UniformLine> _buildOrderLines(
      List<Player> players, List<UniformExtra> extras) {
    final playerLines = players.map(UniformLine.fromPlayer).toList()
      ..sort((a, b) {
        final aNum = a.jerseyNumber;
        final bNum = b.jerseyNumber;
        if (aNum == null && bNum == null) return 0;
        if (aNum == null) return 1;
        if (bNum == null) return -1;
        return aNum.compareTo(bNum);
      });

    final extraLines = extras.map(UniformLine.fromExtra).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return <UniformLine>[...playerLines, ...extraLines];
  }

  Future<void> _exportOrder({
    required BuildContext context,
    required Season season,
    required List<UniformLine> lines,
    required bool numberRequired,
  }) async {
    try {
      final payload = _buildOrderExportPayload(
        season: season,
        lines: lines,
        numberRequired: numberRequired,
      );

      final message = await deliverExcelBytes(
        bytes: payload.bytes,
        fileName: payload.fileName,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      if (payload.hasMissingData) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Se exportó con datos incompletos. Revisa Calidad de datos.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo exportar: $e')),
      );
    }
  }

  Future<void> _shareOrder({
    required BuildContext context,
    required Season season,
    required List<UniformLine> lines,
  }) async {
    try {
      final payload = _buildOrderExportPayload(
        season: season,
        lines: lines,
        numberRequired: _numberRequired,
      );
      await UniformsExporter.shareOrderExcel(
        bytes: payload.bytes,
        filename: payload.fileName,
        seasonName: payload.seasonName,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb
                ? 'En Web no se puede adjuntar automático. Descarga el Excel y adjúntalo en WhatsApp.'
                : 'Archivo listo para compartir por WhatsApp.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo compartir: $e')),
      );
    }
  }

  ({
    Uint8List bytes,
    String fileName,
    String seasonName,
    bool hasMissingData,
  }) _buildOrderExportPayload({
    required Season season,
    required List<UniformLine> lines,
    required bool numberRequired,
  }) {
    final missingCritical =
        lines.where((l) => l.missingSize || l.missingGender).length;
    final missingNumber = lines.where((l) => l.missingNumber).length;
    final hasMissingData =
        missingCritical > 0 || (numberRequired && missingNumber > 0);
    final bytes = UniformsExporter.buildOrderWorkbook(lines);
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final seasonNameFile =
        season.name.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    final fileName = 'pedido_uniformes_${seasonNameFile}_$date.xlsx';
    return (
      bytes: bytes,
      fileName: fileName,
      seasonName: season.name.trim(),
      hasMissingData: hasMissingData,
    );
  }

  Future<void> _exportSizesSummary({
    required BuildContext context,
    required Season season,
    required List<UniformLine> lines,
  }) async {
    try {
      final bytes = UniformsExporter.buildSizesWorkbook(lines);
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final seasonName =
          season.name.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
      final fileName = 'lista_tallas_${seasonName}_$date.xlsx';

      final message = await deliverExcelBytes(
        bytes: bytes,
        fileName: fileName,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo exportar tallas: $e')),
      );
    }
  }

  Future<void> _openExtraDialog(
    BuildContext context,
    String seasonId, {
    UniformExtra? initial,
    required bool canWrite,
  }) async {
    if (!canWrite) return;

    final nameController = TextEditingController(text: initial?.name ?? '');
    final quantityController =
        TextEditingController(text: (initial?.quantity ?? 1).toString());
    final numberController =
        TextEditingController(text: initial?.jerseyNumber?.toString() ?? '');
    final notesController = TextEditingController(text: initial?.notes ?? '');
    String? selectedSize = initial?.jerseySize;
    String? selectedGender = initial?.uniformGender;
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<UniformExtra>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(initial == null ? 'Agregar extra' : 'Editar extra'),
              content: SizedBox(
                width: 460,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          decoration:
                              const InputDecoration(labelText: 'Nombre'),
                          validator: (value) =>
                              (value ?? '').trim().isEmpty ? 'Requerido' : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: quantityController,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Cantidad'),
                          validator: (value) {
                            final quantity = int.tryParse((value ?? '').trim());
                            if (quantity == null || quantity <= 0) {
                              return 'Cantidad inválida';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: numberController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Número # (opcional)'),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: selectedSize,
                          decoration: const InputDecoration(labelText: 'Talla'),
                          items: _jerseySizes
                              .map((size) => DropdownMenuItem(
                                  value: size, child: Text(size)))
                              .toList(),
                          onChanged: (value) =>
                              setStateDialog(() => selectedSize = value),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: selectedGender,
                          decoration:
                              const InputDecoration(labelText: 'Género'),
                          items: _genders
                              .map((gender) => DropdownMenuItem(
                                  value: gender, child: Text(gender)))
                              .toList(),
                          onChanged: (value) =>
                              setStateDialog(() => selectedGender = value),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: notesController,
                          maxLines: 2,
                          decoration: const InputDecoration(labelText: 'Notas'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    final quantity =
                        int.tryParse(quantityController.text.trim()) ?? 1;
                    final number = int.tryParse(numberController.text.trim());
                    Navigator.of(context).pop(
                      UniformExtra(
                        id: initial?.id,
                        seasonId: seasonId,
                        name: nameController.text.trim(),
                        quantity: quantity,
                        jerseyNumber: number,
                        jerseySize: selectedSize,
                        uniformGender: selectedGender,
                        notes: notesController.text.trim().isEmpty
                            ? null
                            : notesController.text.trim(),
                      ),
                    );
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == null) return;
    try {
      await ref.read(uniformsRepoProvider).upsertExtra(saved);
      ref.invalidate(uniformsExtrasBySeasonProvider(seasonId));
    } on PostgrestException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _deleteExtra(
    BuildContext context,
    UniformExtra extra, {
    required bool canWrite,
  }) async {
    if (!canWrite || extra.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar extra'),
        content: Text('¿Eliminar a ${extra.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(uniformsRepoProvider).deleteExtra(extra.id!);
    ref.invalidate(uniformsExtrasBySeasonProvider(extra.seasonId));
  }

  void _showMissingDialog(BuildContext context, List<UniformLine> lines) {
    final missing = lines
        .where((line) =>
            line.missingSize || line.missingGender || line.missingNumber)
        .toList();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Líneas con faltantes'),
        content: SizedBox(
          width: 520,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: missing.length,
            itemBuilder: (context, index) {
              final line = missing[index];
              final fields = <String>[
                if (line.missingSize) 'Talla',
                if (line.missingGender) 'Género',
                if (line.missingNumber) 'Número',
              ];
              return ListTile(
                dense: true,
                title: Text(line.name),
                subtitle: Text('Falta: ${fields.join(', ')}'),
              );
            },
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

class _OrderTab extends StatelessWidget {
  const _OrderTab({
    required this.rows,
    required this.isWeb,
    required this.bottomInset,
    required this.onExport,
    required this.onShare,
    required this.onExportSizes,
  });

  final List<UniformOrderRow> rows;
  final bool isWeb;
  final double bottomInset;
  final VoidCallback onExport;
  final VoidCallback onShare;
  final VoidCallback onExportSizes;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const EmptyState(
        title: 'Sin líneas de pedido',
        message: 'No hay jugadores activos ni extras para esta temporada.',
        icon: Icons.list_alt_outlined,
      );
    }

    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: onExport,
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Exportar Excel'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onShare,
                      icon: const Icon(Icons.share_outlined),
                      label: Text(
                        isWeb
                            ? 'Compartir (WhatsApp Web)'
                            : 'Compartir (WhatsApp)',
                      ),
                    ),
                    if (isWeb)
                      const Tooltip(
                        message:
                            'En Web WhatsApp no permite adjuntar el archivo automático. Primero descarga y luego adjunta manualmente.',
                        child: Icon(Icons.info_outline, size: 20),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: onExportSizes,
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('Exportar tallas'),
                ),
                const SizedBox(height: 6),
                Text(
                  'Nota: En Extras el Número # es opcional.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('No.')),
                  DataColumn(label: Text('Nombre')),
                  DataColumn(label: Text('Número #')),
                  DataColumn(label: Text('Talla')),
                  DataColumn(label: Text('Género')),
                ],
                rows: rows.map((row) {
                  return DataRow(
                    cells: [
                      DataCell(Text('${row.number}')),
                      DataCell(Text(row.name)),
                      DataCell(Text(row.jerseyNumber?.toString() ?? '')),
                      DataCell(Text(row.jerseySize ?? '')),
                      DataCell(Text(row.uniformGender ?? '')),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExtrasTab extends StatelessWidget {
  const _ExtrasTab({
    required this.extras,
    required this.canWrite,
    required this.bottomInset,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final List<UniformExtra> extras;
  final bool canWrite;
  final double bottomInset;
  final VoidCallback onAdd;
  final ValueChanged<UniformExtra> onEdit;
  final ValueChanged<UniformExtra> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: FilledButton.icon(
              onPressed: canWrite ? onAdd : null,
              icon: const Icon(Icons.add),
              label: const Text('Agregar extra'),
            ),
          ),
        ),
        Expanded(
          child: extras.isEmpty
              ? const EmptyState(
                  title: 'Sin extras',
                  message:
                      'Agrega porra, familiares, novia o staff para incluirlos en el pedido.',
                  icon: Icons.group_add_outlined,
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset),
                  itemCount: extras.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final extra = extras[index];
                    return Card(
                      child: ListTile(
                        title: Text(extra.name),
                        subtitle: Text(
                          'Cant: ${extra.quantity} • Num: ${extra.jerseyNumber ?? '-'} • '
                          'Talla: ${extra.jerseySize ?? '-'} • Género: ${extra.uniformGender ?? '-'}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: canWrite ? () => onEdit(extra) : null,
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              onPressed:
                                  canWrite ? () => onDelete(extra) : null,
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
