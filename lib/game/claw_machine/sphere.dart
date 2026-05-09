import 'dart:ui';

import 'package:flame/components.dart';

/// A single colored ball on the floor of the cabinet, or carried under the
/// claw. Drawn as a filled circle with a thin black outline — matches the
/// `_SphereDot` decoration the previous Flutter overlay used.
class SphereComponent extends PositionComponent {
  Color color;

  SphereComponent({
    required this.color,
    required Vector2 position,
    int priority = 1,
  }) : super(
          position: position,
          size: Vector2.all(10),
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
