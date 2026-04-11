import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import '../events.dart';
import '../lexaway_game.dart';
import '../world/scrolling_item_layer.dart';
import 'player.dart';

enum CoinType { coin, diamond }

class Coin extends SpriteAnimationComponent
    with
        HasGameReference<LexawayGame>,
        CollisionCallbacks,
        ScrollingWorldItem {
  final CoinType type;
  @override
  double worldX;
  bool collected = false;

  /// Index into the WorldMap's item list, used for collection tracking.
  @override
  final int itemIndex;

  @override
  double get layerWidth => size.x;

  Coin({required this.type, required this.worldX, this.itemIndex = -1});

  @override
  Future<void> onLoad() async {
    final String path;
    final int frames;
    final double stepTime;

    switch (type) {
      case CoinType.coin:
        path = 'coins/coin.png';
        frames = 5;
        stepTime = 0.15;
      case CoinType.diamond:
        path = 'coins/diamond.png';
        frames = 4;
        stepTime = 0.12;
    }

    final image = await game.images.load(path);
    final sheet = SpriteSheet(image: image, srcSize: Vector2.all(16));

    animation = sheet.createAnimation(row: 0, to: frames, stepTime: stepTime);

    final scale = LexawayGame.pixelScale * 0.5;
    size = Vector2.all(16 * scale);
    paint = Paint()..filterQuality = FilterQuality.none;

    // Sit on the ground surface (no padding offset — coins fill their frame)
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
    if (collected || other is! Player) return;
    collected = true;

    final value = type == CoinType.diamond ? 3 : 1;
    // Sync event — CoinManager reads this coin's position/animation/size
    // from its handler (before removeFromParent propagates) to spawn the
    // fly-to-counter visual effect.
    game.events.emit(CoinCollected(type, value, itemIndex));
    removeFromParent();
  }
}
