import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../events.dart';
import '../lexaway_game.dart';
import '../world/scrolling_item_layer.dart';
import 'player.dart';

/// World-side claw machine cabinet. Static, scrolls with the world like any
/// other [ScrollingWorldItem]; emits [ClawMachineEntered] when the dino
/// bumps into it. Uses a `_triggered` latch so the event fires exactly once
/// per encounter — the manager culls the machine when the screen flow marks
/// it complete.
class ClawMachine extends SpriteComponent
    with
        HasGameReference<LexawayGame>,
        CollisionCallbacks,
        ScrollingWorldItem {
  @override
  double worldX;

  @override
  final int itemIndex;

  bool _triggered = false;

  ClawMachine({required this.worldX, required this.itemIndex});

  @override
  double get layerWidth => size.x;

  /// World-side scale. Full pixelScale (4×) blows the 80×128 cabinet up to
  /// 320×512, ~3× the dino's height. We render at 1:1 source so the
  /// cabinet sits at 80×128 — just slightly taller than the ~106-px dino,
  /// which is what reads as "an arcade machine the dino walks up to" at
  /// in-world scale. Pixel art stays crisp via FilterQuality.none below.
  static const double _scale = 1.0;

  @override
  Future<void> onLoad() async {
    sprite = await Sprite.load('claw_machine/Exterior.png');
    size = sprite!.srcSize * _scale;
    paint = Paint()..filterQuality = FilterQuality.none;

    final groundTop = game.size.y * LexawayGame.groundLevel;
    position.y = groundTop - size.y;

    add(RectangleHitbox());
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (_triggered || other is! Player) return;
    _triggered = true;
    game.events.emit(
      ClawMachineEntered(itemIndex: itemIndex, worldX: worldX),
    );
  }
}
