import 'dart:ui';

import 'package:flame/components.dart';
import '../lexaway_game.dart';
import '../world/scrolling_item_layer.dart';

/// A static scenery sprite (tree, bush, fence, etc.) that scrolls with the ground.
class Entity extends PositionComponent
    with HasGameReference<LexawayGame>, ScrollingWorldItem {
  final Sprite sprite;
  final Vector2 spriteSize;
  @override
  double worldX;

  /// Index into the WorldMap's item list, used for tracking active entities.
  @override
  final int itemIndex;

  @override
  double get layerWidth => spriteSize.x;

  Entity({
    required this.sprite,
    required this.spriteSize,
    required this.worldX,
    this.itemIndex = -1,
  });

  static final Paint _paint = Paint()..filterQuality = FilterQuality.none;

  @override
  void render(Canvas canvas) {
    sprite.render(canvas, size: spriteSize, overridePaint: _paint);
  }
}
