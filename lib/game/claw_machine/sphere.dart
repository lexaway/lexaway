import 'dart:ui';

import 'package:flame/components.dart';

import 'cabinet.dart';

/// A single colored ball on the floor of the cabinet, or carried under the
/// claw. Drawn as a filled circle with a thin black outline — matches the
/// `_SphereDot` decoration the previous Flutter overlay used.
///
/// `position` is the visual center (Anchor.center) and the physics center —
/// `physicsRadius` is slightly under the visual radius so the colored fills
/// touch a hair before the strokes overlap.
class SphereComponent extends PositionComponent with ZoomFaded {
  static const double physicsRadius = 5.5;

  Color color;
  final Vector2 velocity = Vector2.zero();

  SphereComponent({
    required this.color,
    required Vector2 position,
    int priority = 1,
  }) : super(
          position: position,
          size: Vector2.all(12),
          anchor: Anchor.center,
          priority: priority,
        );

  @override
  void render(Canvas canvas) {
    final r = size.x / 2;
    final center = Offset(r, r);
    canvas.drawCircle(center, r - 0.5, Paint()..color = color);
    canvas.drawCircle(
      center,
      r - 0.5,
      Paint()
        ..color = const Color(0xDD000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }
}
