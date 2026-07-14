import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../lexaway_game.dart';

/// Cabinet-local geometry shared by every claw subcomponent.
class ClawCabinet {
  static const double cabW = 88;
  static const double cabH = 136;
  // Glass window bounds, measured from the opaque region of
  // cabinet_mask.png: L9 T18 R78 B76 in the 88×136 art.
  static const double glassTop = 18;
  static const double glassLeft = 9;
  static const double glassRight = 78;
  static const double glassFloorY = 77;
  static const double glassCenterX = (glassLeft + glassRight) / 2;
  // Spool/head — the bulb slice of hook_base.png, rendered 14×14.
  static const double headW = 14;
  static const double headH = 14;
  static const double armOverlap = 10;
  // One claw prong (hook_left / hook_right are a mirrored pair, 16×20).
  static const double armW = 16;
  static const double armH = 20;
  static const double clawRestY = glassTop + 2;
  static const double clawDropY =
      glassFloorY - (headH - armOverlap) - armH;
  static const double captureRadius = 10;
  // Keeps the claw clear of the walls so splayed prongs don't bleed past
  // the frame.
  static const double clawWallPadding = 6;
  static const double clawMinX = glassLeft + clawWallPadding;
  static const double clawMaxX = glassRight - clawWallPadding;
  // Prize hatch — 3-frame sheet (open / half / closed), one 28×20 cell shown.
  static const double prizeDoorX = 29;
  static const double prizeDoorY = 108;
  static const double prizeDoorW = 28;
  static const double prizeDoorH = 20;
  // Joystick — 3-pose sheet, 28×20 cell.
  static const double stickX = 50;
  static const double stickY = 73;
  static const double stickW = 28;
  static const double stickH = 20;
  // Drop button — 2-frame sheet, 12×8 cell.
  static const double buttonX = 16;
  static const double buttonY = 85;
  static const double buttonW = 12;
  static const double buttonH = 8;
  // Console star decoration — 12×12, sits between joystick and button.
  static const double starX = 37;
  static const double starY = 81;
  static const double starW = 12;
  static const double starH = 12;
}

/// Ease-out-cubic mapping of [LexawayGame.zoomBlend] to fade alpha —
/// front-loads the fade so the cabinet reads as "here" early. Shared by
/// [ExteriorComponent] and [ZoomFaded] so they stay in lockstep.
double cabinetFadeAlpha(double blend) {
  final t = blend.clamp(0.0, 1.0);
  final inv = 1.0 - t;
  return 1.0 - inv * inv * inv;
}

/// Fades a component's whole render subtree with the camera zoom blend, so
/// interior pieces ride the same fade as the exterior instead of popping in
/// at full alpha the instant they mount. Composited through one opacity
/// layer.
mixin ZoomFaded on PositionComponent {
  double get _zoomBlend {
    final g = findGame();
    return g is LexawayGame ? g.zoomBlend : 1.0;
  }

  @override
  void renderTree(Canvas canvas) {
    final alpha = cabinetFadeAlpha(_zoomBlend);
    if (alpha <= 0.0) return;
    if (alpha >= 1.0) {
      super.renderTree(canvas);
      return;
    }
    canvas.saveLayer(
      null,
      Paint()..color = Color.fromRGBO(255, 255, 255, alpha),
    );
    super.renderTree(canvas);
    canvas.restore();
  }
}

/// Cabinet exterior — drawn ON TOP of all play-area content so the painted
/// frame masks anything leaking past the window edges (the cutout in
/// cabinet.png is transparent, so the playfield shows through).
///
/// Crossfades on zoom blend between a chunky low-detail sprite (world view)
/// and the full cabinet (encounter view). Both stretch to the same 88×136
/// footprint so the ground anchor and hitbox stay put.
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
    _bigImage = await game.images.load('claw_machine/cabinet.png');
    _littleImage = await game.images.load('claw_machine/little_machine.png');
  }

  @override
  void render(Canvas canvas) {
    final blend = game.zoomBlend;
    final dst = Offset.zero & size.toSize();
    if (blend < 1.0) {
      // Fit at native aspect ratio, bottom-anchored — the source is a
      // 36×36 square, so stretching to 88×136 would distort it.
      final imgW = _littleImage.width.toDouble();
      final imgH = _littleImage.height.toDouble();
      final scale = min(size.x / imgW, size.y / imgH);
      final w = imgW * scale;
      final h = imgH * scale;
      final littleDst = Rect.fromLTWH((size.x - w) / 2, size.y - h, w, h);
      _littlePaint.color =
          Color.fromRGBO(255, 255, 255, 1.0 - cabinetFadeAlpha(blend));
      // Mirror so the joystick lands on the right, matching the big cabinet
      // it crossfades into.
      canvas.save();
      canvas.translate(littleDst.center.dx, 0);
      canvas.scale(-1, 1);
      canvas.translate(-littleDst.center.dx, 0);
      canvas.drawImageRect(
        _littleImage,
        Rect.fromLTWH(0, 0, imgW, imgH),
        littleDst,
        _littlePaint,
      );
      canvas.restore();
    }
    if (blend > 0.0) {
      _bigPaint.color = Color.fromRGBO(255, 255, 255, cabinetFadeAlpha(blend));
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

/// Diagonal highlight over the window cutout. A gradient masked by
/// `cabinet_mask.png` via [BlendMode.dstIn] survives only where the mask
/// is opaque, avoiding a hand-tuned window rect in code.
class GlassShineComponent extends PositionComponent
    with HasGameReference<LexawayGame>, ZoomFaded {
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
    _maskImage = await game.images.load('claw_machine/cabinet_mask.png');
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

/// Cosmetic star between the joystick and drop button. Drawn above the
/// exterior so it reads as part of the control panel.
class ConsoleStarComponent extends PositionComponent
    with HasGameReference<LexawayGame>, ZoomFaded {
  late final Sprite _star;
  late final Paint _paint;

  ConsoleStarComponent()
      : super(
          position: Vector2(ClawCabinet.starX, ClawCabinet.starY),
          size: Vector2(ClawCabinet.starW, ClawCabinet.starH),
          priority: 8,
        );

  @override
  Future<void> onLoad() async {
    _star = Sprite(await game.images.load('claw_machine/star.png'));
    _paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
  }

  @override
  void render(Canvas canvas) {
    _star.render(canvas, size: size, overridePaint: _paint);
  }
}
