import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/animation.dart';

/// Super-saiyan-style aura flashed around the dino when the streak hits 3
/// (the moment he starts running). One-shot, self-removing.
class AuraEffect extends SpriteAnimationComponent {
  static const double _frameW = 25.0;
  static const double _frameH = 24.0;
  static const int _frameCount = 5;
  static const double _stepTime = 0.11;
  static const double _scale = 3.2;

  AuraEffect._({
    required SpriteAnimation animation,
    required Vector2 center,
  }) : super(
          animation: animation,
          size: Vector2(_frameW, _frameH) * _scale,
          anchor: Anchor.center,
          position: center.clone(),
          removeOnFinish: true,
        );

  static Future<AuraEffect> create({
    required Images images,
    required Vector2 center,
  }) async {
    final image = await images.load('fx/aura.png');
    final sheet = SpriteSheet(image: image, srcSize: Vector2(_frameW, _frameH));
    final animation = sheet.createAnimation(
      row: 0,
      from: 0,
      to: _frameCount,
      stepTime: _stepTime,
      loop: false,
    );
    return AuraEffect._(animation: animation, center: center);
  }

  @override
  Future<void> onLoad() async {
    paint = Paint()..filterQuality = FilterQuality.none;
    priority = 3;

    final lifeTime = _frameCount * _stepTime;
    add(
      ScaleEffect.by(
        Vector2.all(1.25),
        EffectController(duration: lifeTime, curve: Curves.easeOut),
      ),
    );
  }
}
