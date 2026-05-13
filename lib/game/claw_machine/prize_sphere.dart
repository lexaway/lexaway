import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';

import '../../data/collectibles/collectible.dart';
import '../../data/collectibles/registry.dart';
import 'sphere.dart';

/// Sphere variant that visually "holds" any [Collectible] inside a
/// translucent two-tone plastic shell. The shell is generic — only the
/// sprite inside changes — so adding a new collectible kind (stickers,
/// hats, vocab cards) doesn't need a new component.
///
/// Extends [SphereComponent] so the existing physics step in
/// `claw_session.dart` keeps working unchanged — only the render is
/// different.
///
/// Renders by pre-composing the whole sphere into a tiny offscreen
/// [ui.Image] at native pixel-art resolution, then drawing that image with
/// [FilterQuality.none]. This is the only way to get the chunky-pixel
/// look: drawing circles directly to the live canvas would let Flutter
/// rasterize them at final screen resolution and produce smooth curves no
/// matter what `isAntiAlias` says.
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
          // [color] is unused by our override but the base class wants it.
          color: shellLeft,
        );

  @override
  Future<void> onLoad() async {
    super.onLoad();
    // Both can be pre-populated by [cloneAt] so a captured/settled sphere
    // appears in the same frame the original was removed — without this
    // guard `composePrizeShellImage` would re-rasterize the shell
    // asynchronously and leave the sphere invisible for a frame or two.
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
  /// reusing this sphere's already-decoded sprite and rasterized shell so
  /// the clone's first frame already has everything to render. Used during
  /// the capture and chute-settle hand-offs to avoid an invisible-sphere
  /// flash.
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

    // Draw the sprite straight from its source image to its slot inside
    // the sphere. We deliberately don't pre-bake the sprite into the
    // composed shell bitmap — that would force a downscale (e.g. 15→8.8
    // pixels for a flag inside a 12-pixel sphere) and drop source pixels
    // with nearest-neighbor sampling. By drawing the raw image through
    // the camera transform, the source pixels map directly to whatever
    // on-screen size the cabinet currently has — one clean scaling step.
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

    // Composed shell (tints, highlight, outline) on top of the sprite.
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

// Memoize composed shells. The shell visual only depends on the pair of
// colors + the pixel size, and the cabinet rolls from a 6-pair palette, so
// at most ~6 distinct images live here per process. Keyed by the tuple so
// reruns hit the cache without recomposing.
final Map<(Color, Color, int), Future<ui.Image>> _shellImageCache = {};

/// Rasterize the shell (tints + highlight + outline, no sprite) into an
/// offscreen [ui.Image] at [pixelSize]×[pixelSize] pixels. The sprite is
/// rendered separately so its source pixels reach the screen via a single
/// scaling step instead of being squeezed through a small bitmap first.
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
/// outline) onto [canvas]. Pixel-art friendly: no antialiasing anywhere
/// and the halves are drawn as filled arcs so there's no soft clip-path
/// edge involved.
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

  // Specular highlight — a chunky pixel block in the upper-left, not a
  // smooth bubble, so it reads as hand-drawn pixel art.
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

  // Black outline on top.
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

/// Three layers used to render a prize sphere that can be cracked open:
/// the raw sprite (passed through, NOT composed — so its pixels stay
/// pristine when the preview upscales it), and the two shell halves
/// rasterized at native pixel-art resolution.
///
/// Note that the sprite is uncomposed deliberately. If we baked it into a
/// 12×12 frame the same way the closed [composePrizeSphereImage] does, the
/// reveal would show a flag that had been downscaled (e.g. 15→~8 px) and
/// then upscaled again for display — the intermediate downscale drops
/// rows/columns with nearest-neighbor sampling, producing a mangled,
/// "ghosted" flag. By skipping that step the preview goes straight from
/// the source PNG to a clean integer-ish upscale.
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
  // Arc fill (the half-disc tint).
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
  // Half-outline (stroked arc, no center fill).
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

/// Shell color pairs the cabinet rolls from per sphere. Pastel pairs so
/// the sprite inside stays legible — saturation/contrast is reserved for
/// the prize itself.
const List<(Color, Color)> shellPalette = [
  (Color(0xFFFF80AB), Color(0xFFFFD180)), // pink + amber
  (Color(0xFF80D8FF), Color(0xFFB9F6CA)), // cyan + mint
  (Color(0xFFE1BEE7), Color(0xFFFFF59D)), // lavender + butter
  (Color(0xFFFFAB91), Color(0xFFB39DDB)), // coral + lilac
  (Color(0xFFA5D6A7), Color(0xFF90CAF9)), // sage + sky
  (Color(0xFFFFCC80), Color(0xFFCE93D8)), // peach + orchid
];

/// Pick a random pair from [shellPalette].
(Color, Color) randomShellPair(math.Random rng) {
  return shellPalette[rng.nextInt(shellPalette.length)];
}
