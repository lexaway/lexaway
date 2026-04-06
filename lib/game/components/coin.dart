import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import '../lexaway_game.dart';

enum CoinType { coin, diamond }

class Coin extends SpriteAnimationComponent
    with HasGameReference<LexawayGame> {
  final CoinType type;
  double worldX;
  bool collected = false;

  Coin({required this.type, required this.worldX});

  factory Coin.fromJson(Map<String, dynamic> json) => Coin(
        type: CoinType.values[json['t'] as int],
        worldX: (json['x'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {'x': worldX, 't': type.index};

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

    final scale = LexawayGame.pixelScale;
    size = Vector2.all(16 * scale);
    paint = Paint()..filterQuality = FilterQuality.none;

    // Sit on the ground surface (no padding offset — coins fill their frame)
    final groundTop = game.size.y * LexawayGame.groundLevel;
    position.y = groundTop - size.y;
  }
}
