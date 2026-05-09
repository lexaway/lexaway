import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../lexaway_game.dart';

/// Cabinet-local geometry shared by every claw subcomponent. Lifted from
/// the old standalone `ClawMachineGame` so positions stay pixel-for-pixel
/// the same after the in-world refactor.
class ClawCabinet {
  static const double cabW = 80;
  static const double cabH = 128;
  // glassTop = 11 lines up with the first fully-transparent row of
  // Exterior.png (the painted ceiling occupies rows 0..10, the window
  // cutout starts at row 11). Setting it to 12 left a 1-pixel transparent
  // strip above the cable origin that no amount of clawRestY tuning could
  // close — visible as a stripe of background showing through across the
  // top of the playfield.
  static const double glassTop = 11;
  static const double glassLeft = 8;
  static const double glassRight = 72;
  static const double glassFloorY = 72;
  static const double glassCenterX = (glassLeft + glassRight) / 2;
  static const double headW = 24;
  static const double headH = 16;
  static const double armOverlap = 10;
  static const double armW = 18;
  static const double armH = 22;
  static const double clawRestY = glassTop + 2;
  static const double clawDropY =
      glassFloorY - (headH - armOverlap) - armH;
  static const double captureRadius = 10;
  static const double prizeDoorX = 10;
  static const double prizeDoorY = 105;
  static const double prizeDoorW = 24;
  static const double prizeDoorH = 20;
  static const double stickX = 48;
  static const double stickY = 70;
  static const double stickW = 24;
  static const double stickH = 27;
  static const double buttonX = 16;
  static const double buttonY = 80;
  static const double buttonW = 16;
  static const double buttonH = 16;
}

/// Cabinet exterior — drawn ON TOP of all play-area content (spheres,
/// claws, head, captured sphere) so the painted frame masks anything
/// that would otherwise leak past the window edges. The window cutout
/// in Exterior.png is transparent, so the playfield shows through it.
class ExteriorComponent extends PositionComponent
    with HasGameReference<LexawayGame> {
  late final Image _image;
  late final Paint _paint;

  ExteriorComponent()
      : super(
          size: Vector2(ClawCabinet.cabW, ClawCabinet.cabH),
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
    with HasGameReference<LexawayGame> {
  late final Image _maskImage;

  static const _gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x99FFFFFF),
      Color(0x22EAF6FF),
      Color(0x66FFFFFF),
    ],
    stops: [0.0, 0.55, 1.0],
  );

  GlassShineComponent()
      : super(
          size: Vector2(ClawCabinet.cabW, ClawCabinet.cabH),
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
