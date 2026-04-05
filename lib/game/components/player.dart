import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import '../lexaway_game.dart';

enum PlayerState { idle, walking }

class Player extends SpriteAnimationGroupComponent<PlayerState>
    with HasGameReference<LexawayGame> {
  static const double _spriteSize = 24;
  static const double _scale = LexawayGame.pixelScale;

  @override
  Future<void> onLoad() async {
    final image = await game.images.load('dino/doux.png');
    final sheet = SpriteSheet(image: image, srcSize: Vector2.all(_spriteSize));

    animations = {
      PlayerState.idle: sheet.createAnimation(
        row: 0,
        from: 0,
        to: 4,
        stepTime: 0.2,
      ),
      PlayerState.walking: sheet.createAnimation(
        row: 0,
        from: 4,
        to: 10,
        stepTime: 0.1,
      ),
    };

    current = PlayerState.idle;
    size = Vector2.all(_spriteSize * _scale);

    // Stand on the ground, 1/4 from left edge
    // Sprite has ~3px transparent padding below feet, so nudge down
    final groundTop = game.size.y * LexawayGame.groundLevel;
    position = Vector2(game.size.x * 0.25, groundTop - size.y + 3 * _scale);

    // Crispy pixel art, no blur
    paint = Paint()..filterQuality = FilterQuality.none;
  }

  void walk() => current = PlayerState.walking;
  void idle() => current = PlayerState.idle;
}
