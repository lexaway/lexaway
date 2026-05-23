import 'dart:math';
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
///
/// Renders two variants and crossfades between them based on the camera's
/// zoom blend: a chunky low-detail sprite for world view (zoom == 1) and
/// the full detailed cabinet for encounter view (zoom > 1). Both stretch
/// to the same 80×128 footprint so the ground anchor and hitbox stay put.
class ExteriorComponent extends PositionComponent
    with HasGameReference<LexawayGame> {
  late final Image _bigImage;
  late final Image _littleImage;
  final Paint _bigPaint = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;
  final Paint _littlePaint = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;

  ExteriorComponent()
      : super(
          size: Vector2(ClawCabinet.cabW, ClawCabinet.cabH),
          priority: 6,
        );

  @override
  Future<void> onLoad() async {
    _bigImage = await game.images.load('claw_machine/Exterior.png');
    _littleImage = await game.images.load('claw_machine/little_machine.png');
  }

  @override
  void render(Canvas canvas) {
    final blend = game.zoomBlend;
    final dst = Offset.zero & size.toSize();
    if (blend < 1.0) {
      // Fit the little sprite inside the cabinet footprint at its native
      // aspect ratio, anchored to the bottom so it sits on the ground.
      // Stretching it to fill 80×128 distorts the artwork (the source is
      // a 36×36 square).
      final imgW = _littleImage.width.toDouble();
      final imgH = _littleImage.height.toDouble();
      final scale = min(size.x / imgW, size.y / imgH);
      final w = imgW * scale;
      final h = imgH * scale;
      final littleDst = Rect.fromLTWH((size.x - w) / 2, size.y - h, w, h);
      _littlePaint.color = Color.fromRGBO(255, 255, 255, 1.0 - blend);
      canvas.drawImageRect(
        _littleImage,
        Rect.fromLTWH(0, 0, imgW, imgH),
        littleDst,
        _littlePaint,
      );
    }
    if (blend > 0.0) {
      _bigPaint.color = Color.fromRGBO(255, 255, 255, blend);
      canvas.drawImageRect(
        _bigImage,
        Rect.fromLTWH(
          0,
          0,
          _bigImage.width.toDouble(),
          _bigImage.height.toDouble(),
        ),
        dst,
        _bigPaint,
      );
    }
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
