import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import '../audio_manager.dart';
import '../lexaway_game.dart';
import 'coin_fly_effect.dart';
import 'player.dart';

enum CoinType { coin, diamond }

class Coin extends SpriteAnimationComponent
    with HasGameReference<LexawayGame>, CollisionCallbacks {
  final CoinType type;
  double worldX;
  bool collected = false;

  /// Index into the WorldMap's item list, used for collection tracking.
  final int itemIndex;

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

  /// Called with (coinValue, itemIndex) when the player collects this coin.
  Function(int value, int itemIndex)? onCollected;

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (collected || other is! Player) return;
    collected = true;

    final value = type == CoinType.diamond ? 3 : 1;
    onCollected?.call(value, itemIndex);

    if (type == CoinType.diamond) {
      AudioManager.instance.playGem();
    } else {
      AudioManager.instance.playCoin();
    }

    // Spawn fly-to-counter effect
    final target = Vector2(game.size.x - 60, 50);
    game.add(
      CoinFlyEffect(
        start: position.clone(),
        target: target,
        animation: animation!.clone(),
        spriteSize: size.clone(),
      ),
    );

    removeFromParent();
  }
}
