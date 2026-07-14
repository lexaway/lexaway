import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';

import '../../data/collectibles/collectible.dart';
import '../../data/collectibles/registry.dart';
import 'sphere.dart';

/// Sphere variant that "holds" any [Collectible] inside a translucent
/// two-tone shell. Shell is generic, so new collectible kinds need no new
/// component. Extends [SphereComponent] so the physics step in
/// `claw_session.dart` works unchanged; only the render differs.
///
/// Pre-composes the sphere into an offscreen [ui.Image] at native pixel
/// resolution, then draws it with [FilterQuality.none] — drawing circles
/// straight to the live canvas would rasterize at screen resolution and
/// smooth the curves regardless of `isAntiAlias`.
class PrizeSphereComponent extends SphereComponent {
  static const int nativePixelSize = 12;
  static const double _innerScale = 1.6;

  final Collectible collectible;
  final Color shellLeft;
  final Color shellRight;

  ui.Image? _sprite;
  ui.Image? _shell;

  PrizeSphereComponent({
    required this.collectible,
    required this.shellLeft,
    required this.shellRight,
    required super.position,
    super.priority = 1,
  }) : super(
          // Unused by our override, but the base class requires it.
          color: shellLeft,
        );

  @override
  Future<void> onLoad() async {
    super.onLoad();
    // May be pre-populated by [cloneAt]; the ??= guard avoids an async
    // re-rasterize that would leave the sphere invisible for a frame or two.
    _sprite ??=
        CollectibleRegistry.instance.cachedSprite(collectible.spriteAsset) ??
            await CollectibleRegistry.instance
                .loadSprite(collectible.spriteAsset);
    _shell ??= await composePrizeShellImage(
      shellLeft: shellLeft,
      shellRight: shellRight,
      pixelSize: nativePixelSize,
    );
  }

  /// Spawn a new sphere with the same collectible + shell at [position],
  /// reusing this sphere's decoded sprite and shell so the clone renders on
  /// its first frame. Avoids an invisible-sphere flash on capture/settle
  /// hand-offs.
  PrizeSphereComponent cloneAt({
    required Vector2 position,
    int priority = 1,
  }) {
    final clone = PrizeSphereComponent(
      collectible: collectible,
      shellLeft: shellLeft,
      shellRight: shellRight,
      position: position,
      priority: priority,
    );
    clone._sprite = _sprite;
    clone._shell = _shell;
    return clone;
  }

  @override
  void render(Canvas canvas) {
    final sprite = _sprite;
    final shell = _shell;
    if (sprite == null || shell == null) return;

    // Draw the sprite straight from source, NOT pre-baked into the shell
    // bitmap: baking would force a downscale (e.g. 15→8.8 px) that drops
    // source pixels via nearest-neighbor. Drawing raw keeps it one clean
    // scaling step to the on-screen size.
    final fw = sprite.width.toDouble();
    final fh = sprite.height.toDouble();
    final radius = size.x / 2 - 0.5;
    final scale = (radius * _innerScale) / fw;
    final dstW = fw * scale;
    final dstH = fh * scale;
    canvas.drawImageRect(
      sprite,
      Rect.fromLTWH(0, 0, fw, fh),
      Rect.fromLTWH(
        size.x / 2 - dstW / 2,
        size.y / 2 - dstH / 2,
        dstW,
        dstH,
      ),
      Paint()
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false,
    );

    // Composed shell on top of the sprite.
    canvas.drawImageRect(
      shell,
      Rect.fromLTWH(0, 0, shell.width.toDouble(), shell.height.toDouble()),
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false,
    );
  }
}

// Memoized composed shells, keyed by (colors, pixelSize). ~6 distinct
// images per process (6-pair palette).
final Map<(Color, Color, int), Future<ui.Image>> _shellImageCache = {};

/// Rasterize the shell (no sprite) into an offscreen [ui.Image] at
/// [pixelSize]×[pixelSize]. Sprite is rendered separately so its pixels
/// reach the screen in one scaling step.
Future<ui.Image> composePrizeShellImage({
  required Color shellLeft,
  required Color shellRight,
  int pixelSize = PrizeSphereComponent.nativePixelSize,
}) {
  final key = (shellLeft, shellRight, pixelSize);
  final cached = _shellImageCache[key];
  if (cached != null) return cached;
  final fut = () async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _paintShellOnly(
      canvas,
      center: Offset(pixelSize / 2, pixelSize / 2),
      radius: pixelSize / 2 - 0.5,
      shellLeft: shellLeft,
      shellRight: shellRight,
    );
    final picture = recorder.endRecording();
    return picture.toImage(pixelSize, pixelSize);
  }();
  _shellImageCache[key] = fut;
  return fut;
}

/// Draw the shell (two translucent half-discs + specular highlight +
/// outline) onto [canvas]. No antialiasing, and halves are filled arcs to
/// avoid a soft clip-path edge.
void _paintShellOnly(
  Canvas canvas, {
  required Offset center,
  required double radius,
  required Color shellLeft,
  required Color shellRight,
}) {
  final circleRect = Rect.fromCircle(center: center, radius: radius);

  // Left half-disc: π/2 → 3π/2 (top, through left, to bottom).
  canvas.drawArc(
    circleRect,
    math.pi / 2,
    math.pi,
    true,
    Paint()
      ..color = shellLeft.withAlpha(80)
      ..isAntiAlias = false,
  );
  // Right half-disc: -π/2 → π/2 (top, through right, to bottom).
  canvas.drawArc(
    circleRect,
    -math.pi / 2,
    math.pi,
    true,
    Paint()
      ..color = shellRight.withAlpha(80)
      ..isAntiAlias = false,
  );

  // Chunky pixel block, not a smooth bubble, so it reads as pixel art.
  final hSize = (radius * 0.4).floorToDouble();
  canvas.drawRect(
    Rect.fromLTWH(
      (center.dx - radius * 0.55).floorToDouble(),
      (center.dy - radius * 0.55).floorToDouble(),
      hSize,
      hSize,
    ),
    Paint()
      ..color = const Color(0x80FFFFFF)
      ..isAntiAlias = false,
  );

  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..color = const Color(0xDD000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..isAntiAlias = false,
  );
}

/// Three layers for a crackable prize sphere: the raw sprite (uncomposed,
/// so its pixels stay pristine when the preview upscales) and the two shell
/// halves at native resolution.
///
/// The sprite is uncomposed deliberately: baking it into a 12×12 frame
/// would downscale (e.g. 15→~8 px) then upscale, and the intermediate
/// nearest-neighbor downscale drops rows/columns into a "ghosted" flag.
/// Skipping it goes straight from source PNG to a clean upscale.
class PrizeSphereLayers {
  /// The collectible's source image (not pre-rasterized into a sphere
  /// frame). Callers render this directly at native res for pristine
  /// pixel-art reveal.
  final ui.Image sprite;
  final ui.Image leftHalf;
  final ui.Image rightHalf;
  /// Pixel size the shell halves were rasterized at — needed so the
  /// preview can size the sprite to match the shell's interior.
  final int pixelSize;
  /// Inner-radius scale factor used when composing the shell (matches the
  /// `radius * 1.6` rule in [paintPrizeSphere]). Lets the preview place
  /// the sprite over the same area the shell covers.
  final double innerScale;
  const PrizeSphereLayers({
    required this.sprite,
    required this.leftHalf,
    required this.rightHalf,
    required this.pixelSize,
    required this.innerScale,
  });
}

/// Compose just the shell halves at native pixel resolution and return
/// them alongside the raw sprite. The closed-sphere look is recovered by
/// stacking sprite → leftHalf → rightHalf with no offsets.
Future<PrizeSphereLayers> composePrizeSphereLayers({
  required ui.Image sprite,
  required Color shellLeft,
  required Color shellRight,
  int pixelSize = PrizeSphereComponent.nativePixelSize,
}) async {
  final center = Offset(pixelSize / 2, pixelSize / 2);
  final radius = pixelSize / 2 - 0.5;
  final leftLayer = await _composeAt(pixelSize, (canvas) {
    _paintShellHalf(
      canvas,
      center: center,
      radius: radius,
      tint: shellLeft,
      isLeft: true,
    );
  });
  final rightLayer = await _composeAt(pixelSize, (canvas) {
    _paintShellHalf(
      canvas,
      center: center,
      radius: radius,
      tint: shellRight,
      isLeft: false,
    );
  });
  return PrizeSphereLayers(
    sprite: sprite,
    leftHalf: leftLayer,
    rightHalf: rightLayer,
    pixelSize: pixelSize,
    innerScale: 1.6,
  );
}

Future<ui.Image> _composeAt(int pixelSize, void Function(Canvas) draw) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  draw(canvas);
  final picture = recorder.endRecording();
  return picture.toImage(pixelSize, pixelSize);
}

/// Paints one half-disc of shell tint + the matching half of the black
/// outline. The left half also paints the specular highlight (a chunky
/// upper-left pixel block).
void _paintShellHalf(
  Canvas canvas, {
  required Offset center,
  required double radius,
  required Color tint,
  required bool isLeft,
}) {
  final rect = Rect.fromCircle(center: center, radius: radius);
  canvas.drawArc(
    rect,
    isLeft ? math.pi / 2 : -math.pi / 2,
    math.pi,
    true,
    Paint()
      ..color = tint.withAlpha(80)
      ..isAntiAlias = false,
  );
  if (isLeft) {
    // Specular highlight lives on the left half.
    final hSize = (radius * 0.4).floorToDouble();
    canvas.drawRect(
      Rect.fromLTWH(
        (center.dx - radius * 0.55).floorToDouble(),
        (center.dy - radius * 0.55).floorToDouble(),
        hSize,
        hSize,
      ),
      Paint()
        ..color = const Color(0x80FFFFFF)
        ..isAntiAlias = false,
    );
  }
  canvas.drawArc(
    rect,
    isLeft ? math.pi / 2 : -math.pi / 2,
    math.pi,
    false,
    Paint()
      ..color = const Color(0xDD000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..isAntiAlias = false,
  );
}

/// Shell color pairs, one rolled per sphere. Pastels so the sprite inside
/// stays legible.
const List<(Color, Color)> shellPalette = [
  (Color(0xFFFF80AB), Color(0xFFFFD180)), // pink + amber
  (Color(0xFF80D8FF), Color(0xFFB9F6CA)), // cyan + mint
  (Color(0xFFE1BEE7), Color(0xFFFFF59D)), // lavender + butter
  (Color(0xFFFFAB91), Color(0xFFB39DDB)), // coral + lilac
  (Color(0xFFA5D6A7), Color(0xFF90CAF9)), // sage + sky
  (Color(0xFFFFCC80), Color(0xFFCE93D8)), // peach + orchid
];

(Color, Color) randomShellPair(math.Random rng) {
  return shellPalette[rng.nextInt(shellPalette.length)];
}
