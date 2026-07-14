import 'dart:math';
import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/animation.dart';

import '../lexaway_game.dart';

/// Burst of twinkling sparks around the dino, rewarding streak milestones
/// (every multiple of 10). Staggered one-shot sparks that self-remove.
class SparkBurstEffect extends PositionComponent {
  static const double _frameW = 45.0;
  static const double _frameH = 35.0;
  static const int _frameCount = 6;
  static const double _stepTime = 0.07;
  static const double _baseScale = 1.6;
  static const int _sparkCount = 6;
  static const double _stagger = 0.06;

  static final _rng = Random();

  final Vector2 _origin;
  final SpriteAnimation _animation;

  SparkBurstEffect._({
    required Vector2 origin,
    required SpriteAnimation animation,
  })  : _origin = origin,
        _animation = animation;

  static Future<SparkBurstEffect> create({
    required Images images,
    required Vector2 origin,
  }) async {
    final image = await images.load('fx/spark.png');
    final sheet = SpriteSheet(image: image, srcSize: Vector2(_frameW, _frameH));
    final animation = sheet.createAnimation(
      row: 0,
      from: 0,
      to: _frameCount,
      stepTime: _stepTime,
      loop: false,
    );
    return SparkBurstEffect._(origin: origin, animation: animation);
  }

  @override
  Future<void> onLoad() async {
    priority = 3;
    final lifeTime = _frameCount * _stepTime;
    final scale = LexawayGame.pixelScale;
    final spreadX = 16 * scale;
    final spreadY = 14 * scale;
    final drift = 6 * scale;

    for (var i = 0; i < _sparkCount; i++) {
      final dx = (_rng.nextDouble() - 0.5) * spreadX * 2;
      final dy = (_rng.nextDouble() - 0.5) * spreadY * 2;
      final sizeJitter = 0.7 + _rng.nextDouble() * 0.5;
      final delay = i * _stagger;

      final spark = SpriteAnimationComponent(
        animation: _animation.clone(),
        size: Vector2(_frameW, _frameH) * (_baseScale * sizeJitter),
        anchor: Anchor.center,
        position: _origin + Vector2(dx, dy),
        removeOnFinish: true,
      )
        ..paint = (Paint()..filterQuality = FilterQuality.none)
        ..priority = 3
        ..playing = false;

      // Stagger starts so the burst shimmers instead of a single hard pop.
      spark.add(
        TimerComponent(
          period: delay,
          removeOnFinish: true,
          onTick: () => spark.playing = true,
        ),
      );
      spark.add(
        MoveByEffect(
          Vector2(0, -drift),
          EffectController(
            duration: lifeTime,
            startDelay: delay,
            curve: Curves.easeOut,
          ),
        ),
      );

      add(spark);
    }

    // Self-remove after the last staggered sparkle finishes.
    add(
      TimerComponent(
        period: lifeTime + _sparkCount * _stagger + 0.1,
        removeOnFinish: true,
        onTick: removeFromParent,
      ),
    );
  }
}
