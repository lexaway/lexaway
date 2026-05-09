import 'dart:ui';

import 'package:flame/components.dart';

import '../claw_machine_game.dart';

/// Bottom-left prize hatch on the cabinet. Swaps between PrizeDoor1 (closed)
/// and PrizeDoor2 (open) based on [ClawMachineGame.doorOpen].
class PrizeDoorComponent extends PositionComponent
    with HasGameReference<ClawMachineGame> {
  late final Sprite _closed;
  late final Sprite _open;
  late final Paint _paint;

  PrizeDoorComponent()
      : super(
          position: Vector2(
            ClawMachineGame.prizeDoorX,
            ClawMachineGame.prizeDoorY,
          ),
          size: Vector2(
            ClawMachineGame.prizeDoorW,
            ClawMachineGame.prizeDoorH,
          ),
          priority: 8,
        );

  @override
  Future<void> onLoad() async {
    final closedImg =
        await game.images.load('claw_machine/PrizeDoor1.png');
    final openImg = await game.images.load('claw_machine/PrizeDoor2.png');
    _closed = Sprite(closedImg);
    _open = Sprite(openImg);
    _paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
  }

  @override
  void render(Canvas canvas) {
    final sprite = game.doorOpen ? _open : _closed;
    sprite.render(canvas, size: size, overridePaint: _paint);
  }
}
