import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../claw_machine_game.dart';

/// Cabinet exterior — drawn ON TOP of all play-area content (spheres,
/// claws, head, captured sphere) so the painted frame masks anything
/// that would otherwise leak past the window edges. The window cutout
/// in Exterior.png is transparent, so the playfield shows through it.
class ExteriorComponent extends PositionComponent
    with HasGameReference<ClawMachineGame> {
  late final Image _image;
  late final Paint _paint;

  ExteriorComponent()
      : super(
          size: Vector2(ClawMachineGame.cabW, ClawMachineGame.cabH),
          priority: 6,
        );

  @override
  Future<void> onLoad() async {
    _image = await game.images.load('claw_machine/Exterior.png');
    _paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
  }

  @override
  void render(Canvas canvas) {
    canvas.drawImageRect(
      _image,
      Rect.fromLTWH(0, 0, _image.width.toDouble(), _image.height.toDouble()),
      Offset.zero & size.toSize(),
      _paint,
    );
  }
}

/// Subtle diagonal highlight over the window cutout. Renders a gradient
/// then composites the artist's `ExteriorMask.png` (opaque pixels mark
/// the window region) with [BlendMode.dstIn], so the gradient survives
/// only where the mask is opaque. Saves us from hand-tuning the window
/// rect in code.
class GlassShineComponent extends PositionComponent
    with HasGameReference<ClawMachineGame> {
  late final Image _maskImage;

  static const _gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x40FFFFFF),
      Color(0x10FFFFFF),
      Color(0x28FFFFFF),
    ],
    stops: [0.0, 0.55, 1.0],
  );

  GlassShineComponent()
      : super(
          size: Vector2(ClawMachineGame.cabW, ClawMachineGame.cabH),
          priority: 7,
        );

  @override
  Future<void> onLoad() async {
    _maskImage = await game.images.load('claw_machine/ExteriorMask.png');
  }

  @override
  void render(Canvas canvas) {
    final bounds = Offset.zero & size.toSize();
    canvas.saveLayer(bounds, Paint());
    canvas.drawRect(
      bounds,
      Paint()..shader = _gradient.createShader(bounds),
    );
    canvas.drawImageRect(
      _maskImage,
      Rect.fromLTWH(
        0,
        0,
        _maskImage.width.toDouble(),
        _maskImage.height.toDouble(),
      ),
      bounds,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false,
    );
    canvas.restore();
  }
}
