import 'dart:ui';

import 'package:flame/components.dart';
import '../lexaway_game.dart';

/// A static scenery sprite (tree, bush, fence, etc.) that scrolls with the ground.
class Entity extends PositionComponent with HasGameReference<LexawayGame> {
  final Sprite sprite;
  final Vector2 spriteSize;
  double worldX;

  Entity({
    required this.sprite,
    required this.spriteSize,
    required this.worldX,
  });

  static final Paint _paint = Paint()..filterQuality = FilterQuality.none;

  @override
  void render(Canvas canvas) {
    sprite.render(canvas, size: spriteSize, overridePaint: _paint);
  }
}
