import '../../players/domain/player.dart';
import 'uniform_extra.dart';

class UniformLine {
  const UniformLine({
    required this.qty,
    required this.name,
    this.jerseyNumber,
    this.jerseySize,
    this.uniformGender,
    required this.type,
    required this.isExtra,
    this.missingPhoto = false,
    this.playerId,
    this.extraId,
  });

  final int qty;
  final String name;
  final int? jerseyNumber;
  final String? jerseySize;
  final String? uniformGender;
  final String type;
  final bool isExtra;
  final bool missingPhoto;
  final String? playerId;
  final String? extraId;

  bool get missingSize => (jerseySize ?? '').trim().isEmpty;
  bool get missingGender => (uniformGender ?? '').trim().isEmpty;
  bool get missingNumber =>
      !isExtra && (jerseyNumber == null || jerseyNumber! <= 0);

  factory UniformLine.fromPlayer(Player player) {
    final jerseyDisplayName = (player.jerseyName ?? '').trim();
    return UniformLine(
      qty: 1,
      name: jerseyDisplayName.isEmpty ? player.firstName : jerseyDisplayName,
      jerseyNumber: player.jerseyNumber,
      jerseySize: player.jerseySize,
      uniformGender: player.uniformGender,
      type: 'Jugador',
      isExtra: false,
      missingPhoto: (player.photoPath ?? '').trim().isEmpty,
      playerId: player.id,
    );
  }

  factory UniformLine.fromExtra(UniformExtra extra) {
    return UniformLine(
      qty: extra.quantity,
      name: extra.name,
      jerseyNumber: extra.jerseyNumber,
      jerseySize: extra.jerseySize,
      uniformGender: extra.uniformGender,
      type: 'Extra',
      isExtra: true,
      extraId: extra.id,
    );
  }
}
