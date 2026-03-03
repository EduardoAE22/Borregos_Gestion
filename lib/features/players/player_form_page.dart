import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/logger.dart';
import '../../shared/widgets/loading.dart';
import '../auth/providers/auth_providers.dart';
import '../seasons/providers/seasons_providers.dart';
import 'data/players_repo.dart';
import 'domain/player.dart';
import 'providers/player_photo_providers.dart';
import 'providers/players_providers.dart';

class PlayerFormPage extends ConsumerStatefulWidget {
  const PlayerFormPage({
    super.key,
    this.playerId,
  });

  final String? playerId;

  bool get isEdit => playerId != null;

  @override
  ConsumerState<PlayerFormPage> createState() => _PlayerFormPageState();
}

class _PlayerFormPageState extends ConsumerState<PlayerFormPage> {
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
  static const List<String> _genders = <String>[
    'H',
    'M',
    'Niña',
    'Niño',
  ];

  final _formKey = GlobalKey<FormState>();
  final _jerseyController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _jerseyNameController = TextEditingController();
  final _positionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emergencyController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isActive = true;
  bool _saving = false;
  bool _initialized = false;
  String? _selectedJerseySize;
  String? _selectedGender;
  String? _photoPath;
  String? _photoThumbPath;
  Uint8List? _selectedPhotoBytes;
  String? _selectedPhotoName;

  @override
  void dispose() {
    _jerseyController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _jerseyNameController.dispose();
    _positionController.dispose();
    _phoneController.dispose();
    _emergencyController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    AppLogger.info('Nav',
        'Entrando a ${widget.isEdit ? 'Editar jugador' : 'Nuevo jugador'} @ ${DateTime.now().toIso8601String()}');
  }

  void _loadFromPlayer(Player player) {
    if (_initialized) return;
    _jerseyController.text = player.jerseyNumber.toString();
    _firstNameController.text = player.firstName;
    _lastNameController.text = player.lastName;
    _jerseyNameController.text = player.jerseyName ?? '';
    _positionController.text = player.position ?? '';
    _selectedJerseySize = player.jerseySize;
    _selectedGender = player.uniformGender;
    _phoneController.text = player.phone ?? '';
    _emergencyController.text = player.emergencyContact ?? '';
    _ageController.text = player.age?.toString() ?? '';
    _heightController.text = player.heightCm?.toString() ?? '';
    _weightController.text = player.weightKg?.toString() ?? '';
    _notesController.text = player.notes ?? '';
    _isActive = player.isActive;
    _photoPath = player.photoPath;
    _photoThumbPath = player.photoThumbPath;
    _initialized = true;
  }

  int? _toInt(String text) {
    final value = text.trim();
    if (value.isEmpty) return null;
    return int.tryParse(value);
  }

  double? _toDouble(String text) {
    final value = text.trim();
    if (value.isEmpty) return null;
    return double.tryParse(value);
  }

  String _mapPlayerSaveError(PostgrestException e) {
    final raw = '${e.message} ${e.details ?? ''} ${e.hint ?? ''}'.toLowerCase();
    final isUniqueViolation = e.code == '23505' || raw.contains('unique');
    if (raw.contains('players_jersey_unique') ||
        (isUniqueViolation &&
            (raw.contains('jersey') || raw.contains('numero')))) {
      return 'El numero de jersey ya existe en la temporada activa.';
    }
    return e.message;
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    try {
      final bytes = await picked.readAsBytes();
      setState(() {
        _selectedPhotoBytes = bytes;
        _selectedPhotoName = picked.name;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No se pudo leer la imagen seleccionada.')),
      );
    }
  }

  Future<void> _save(
      {String? existingSeasonId, String? existingPlayerId}) async {
    final canWrite =
        ref.read(currentProfileProvider).valueOrNull?.canWriteGeneral ?? false;
    if (!canWrite) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    try {
      final repo = ref.read(playersRepoProvider);
      final season = await ref.read(activeSeasonProvider.future);
      final seasonId = existingSeasonId ?? season?.id;

      if (seasonId == null) {
        throw Exception('No hay temporada activa.');
      }

      final player = Player(
        id: existingPlayerId,
        seasonId: seasonId,
        jerseyNumber: int.parse(_jerseyController.text.trim()),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        jerseyName: _jerseyNameController.text.trim().isEmpty
            ? null
            : _jerseyNameController.text.trim(),
        position: _positionController.text.trim().isEmpty
            ? null
            : _positionController.text.trim(),
        jerseySize: _selectedJerseySize,
        uniformGender: _selectedGender,
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        emergencyContact: _emergencyController.text.trim().isEmpty
            ? null
            : _emergencyController.text.trim(),
        age: _toInt(_ageController.text),
        heightCm: _toInt(_heightController.text),
        weightKg: _toDouble(_weightController.text),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        photoPath: widget.isEdit ? _photoPath : null,
        isActive: _isActive,
      );

      final saved = await repo.upsertPlayer(player);

      if (_selectedPhotoBytes != null && _selectedPhotoName != null) {
        final uploaded = await repo.uploadPlayerPhoto(
          seasonId: seasonId,
          playerId: saved.id!,
          filename: _selectedPhotoName!,
          bytes: _selectedPhotoBytes!,
          oldPhotoPath: _photoPath,
          oldPhotoThumbPath: _photoThumbPath,
        );

        if (!mounted) return;
        setState(() {
          _photoPath = uploaded.photoPath;
          _photoThumbPath = uploaded.photoThumbPath;
          _selectedPhotoBytes = null;
          _selectedPhotoName = null;
        });
      }

      if (!mounted) return;
      ref.invalidate(playersByActiveSeasonProvider);
      ref.invalidate(playersBySeasonProvider(seasonId));
      ref.invalidate(playerByIdProvider(saved.id!));
      context.pop();
    } on PostgrestException catch (e) {
      AppLogger.supabaseError(e, scope: 'Players.save');
      final message = _mapPlayerSaveError(e);

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } on PlayerPhotoUploadValidationException catch (e) {
      AppLogger.info(
          'Players.save', 'PlayerPhotoUploadValidationException: ${e.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } on PlayerPhotoFormatException catch (e) {
      AppLogger.info(
          'Players.save', 'PlayerPhotoFormatException: ${e.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } on StorageException catch (e) {
      AppLogger.info('Players.save', 'StorageException: ${e.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error subiendo foto: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(
          title: Text(widget.isEdit ? 'Editar jugador' : 'Nuevo jugador')),
      body: profileAsync.when(
        data: (profile) {
          final canWrite = profile?.canWriteGeneral ?? false;
          if (!canWrite) {
            return const Center(
                child: Text('Tu rol no tiene permisos para editar jugadores.'));
          }

          if (!widget.isEdit) {
            return _buildForm(
              onSave: () => _save(),
              onUploadPhoto: _pickPhoto,
            );
          }

          final playerAsync = ref.watch(playerByIdProvider(widget.playerId!));
          return playerAsync.when(
            data: (player) {
              if (player == null) {
                return const Center(child: Text('Jugador no encontrado.'));
              }
              _loadFromPlayer(player);
              return _buildForm(
                onSave: () => _save(
                    existingSeasonId: player.seasonId,
                    existingPlayerId: player.id),
                onUploadPhoto: _pickPhoto,
              );
            },
            loading: () => const Loading(message: 'Cargando jugador...'),
            error: (error, stack) => Center(child: Text('Error: $error')),
          );
        },
        loading: () => const Loading(message: 'Cargando permisos...'),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildForm({
    required VoidCallback onSave,
    required VoidCallback? onUploadPhoto,
  }) {
    final previewPhotoAsync =
        ref.watch(playerPhotoSignedUrlProvider(_photoThumbPath ?? _photoPath));
    final previewPhotoUrl = previewPhotoAsync.valueOrNull;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedPhotoBytes != null)
              Center(
                child: CircleAvatar(
                  radius: 42,
                  backgroundImage: MemoryImage(_selectedPhotoBytes!),
                ),
              )
            else if ((previewPhotoUrl ?? '').trim().isNotEmpty)
              Center(
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: ClipOval(
                    child: Image.network(
                      previewPhotoUrl!,
                      key: ValueKey(previewPhotoUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: Color(0xFFE0E0E0),
                        child: Center(child: Icon(Icons.person_outline)),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Center(
              child: OutlinedButton.icon(
                onPressed: _saving ? null : onUploadPhoto,
                icon: const Icon(Icons.image_outlined),
                label: Text(
                  _selectedPhotoName == null
                      ? 'Elegir foto'
                      : 'Foto seleccionada',
                ),
              ),
            ),
            TextFormField(
              controller: _jerseyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '# Jersey'),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) return 'Requerido';
                if (int.tryParse(value!.trim()) == null) {
                  return 'Debe ser numero';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _firstNameController,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _lastNameController,
              decoration: const InputDecoration(labelText: 'Apellido'),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _jerseyNameController,
              decoration: const InputDecoration(
                labelText: 'Nombre en jersey (apodo)',
                helperText:
                    "Así se imprimirá en el uniforme. Ej: 'EL CAPI', 'NANO', 'CASTILLO'",
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _positionController,
              decoration: const InputDecoration(labelText: 'Posicion'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedJerseySize,
                    decoration: const InputDecoration(labelText: 'Talla'),
                    items: _jerseySizes
                        .map(
                          (size) => DropdownMenuItem<String>(
                            value: size,
                            child: Text(size),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) =>
                            setState(() => _selectedJerseySize = value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedGender,
                    decoration: const InputDecoration(labelText: 'Genero'),
                    items: _genders
                        .map(
                          (gender) => DropdownMenuItem<String>(
                            value: gender,
                            child: Text(gender),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _selectedGender = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Telefono'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _emergencyController,
              decoration:
                  const InputDecoration(labelText: 'Contacto emergencia'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Edad'),
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (text.isEmpty) return null;
                      final age = int.tryParse(text);
                      if (age == null) return 'Debe ser numero';
                      if (age < 3 || age > 80) return 'Edad invalida (3-80)';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _heightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Altura (cm)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _weightController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Peso (kg)'),
                  ),
                ),
              ],
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
              onChanged: _saving ? null : (v) => setState(() => _isActive = v),
              title: const Text('Jugador activo'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : onSave,
                child: Text(_saving ? 'Guardando...' : 'Guardar jugador'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
