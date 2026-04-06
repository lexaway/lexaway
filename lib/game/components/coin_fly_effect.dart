import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';

/// Animated coin sprite that flies from its collection point up to the
/// coin counter in the top-right corner, then removes itself.
class CoinFlyEffect extends SpriteAnimationComponent {
  static const double _duration = 0.45;

  final Vector2 _target;

  CoinFlyEffect({
    required Vector2 start,
    required Vector2 target,
    required SpriteAnimation animation,
    required Vector2 spriteSize,
  }) : _target = target,
       super(
         animation: animation,
         size: spriteSize.clone(),
         position: start.clone(),
       );

  @override
  Future<void> onLoad() async {
    paint = Paint()..filterQuality = FilterQuality.none;
    priority = 100;

    final controller = EffectController(
      duration: _duration,
      curve: Curves.easeInCubic,
    );

    add(MoveEffect.to(_target, controller));
    add(
      ScaleEffect.to(
        Vector2.all(0.4),
        EffectController(duration: _duration, curve: Curves.easeIn),
      ),
    );
    add(RemoveEffect(delay: _duration));
  }
}
