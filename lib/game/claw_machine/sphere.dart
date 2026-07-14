import 'dart:ui';

import 'package:flame/components.dart';

import 'cabinet.dart';

/// A single colored ball on the cabinet floor or carried under the claw.
/// Filled circle with a thin black outline.
///
/// `position` is both visual (Anchor.center) and physics center;
/// `physicsRadius` sits just under the visual radius so fills touch a hair
/// before strokes overlap.
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
