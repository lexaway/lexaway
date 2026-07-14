import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';

import '../lexaway_game.dart';
import '../world/biome_definition.dart';
import '../world/scrolling_item_layer.dart';
import 'behaviors/behavior_config.dart';
import 'behaviors/creature_behavior_component.dart';

enum CreatureAnim { idle, hop, hit, death }

/// Ambient animated critter that rides world scroll. Behavior lives in
/// composable child components (see `behaviors/`); this class is just the
/// visual shell — sprite sheet, animation playback, and an API behaviors call.
class Creature extends SpriteAnimationGroupComponent<CreatureAnim>
    with HasGameReference<LexawayGame>, ScrollingWorldItem {
  final String sheetPath;
  final double frameWidth;
  final double frameHeight;
  final double spriteScale;
  final CreatureAnimConfig animConfig;
  final List<BehaviorConfig> behaviorConfigs;
  final List<Color> tintPalette;
  final int sourceDownsample;

  @override
  double worldX;

  @override
  final int itemIndex;

  /// Per-creature RNG seeded from the unique world item index. Behaviors
  /// derive their own RNGs from this so each critter acts independently.
  final Random rng;


  Creature({
    required this.sheetPath,
    required this.frameWidth,
    required this.frameHeight,
    required this.spriteScale,
    required this.animConfig,
    required this.behaviorConfigs,
    required this.worldX,
    required this.itemIndex,
    this.tintPalette = const [],
    this.sourceDownsample = 1,
  }) : rng = Random(itemIndex);

  /// True when any child behavior has taken exclusive control (fleeing, etc.).
  bool get isExcited => children
      .whereType<CreatureBehaviorComponent>()
      .any((b) => b.isExclusive);

  @override
  double get layerWidth => size.x;

  @override
  Future<void> onLoad() async {
    var image = await game.images.load(sheetPath);
    var srcW = frameWidth;
    var srcH = frameHeight;
    if (sourceDownsample > 1) {
      assert(
        frameWidth % sourceDownsample == 0 &&
            frameHeight % sourceDownsample == 0 &&
            image.width % sourceDownsample == 0 &&
            image.height % sourceDownsample == 0,
        'sourceDownsample must evenly divide frame & sheet dimensions — '
        'otherwise decimated frame stride drifts and SpriteSheet walks '
        'off-by-one across frames (sheet=${image.width}x${image.height}, '
        'frame=${frameWidth}x$frameHeight, factor=$sourceDownsample)',
      );
      // TODO: cache the decimated Image per (sheetPath, factor) — currently
      // every creature re-runs PictureRecorder → toImage on spawn.
      image = await _decimate(image, sourceDownsample);
      srcW = frameWidth / sourceDownsample;
      srcH = frameHeight / sourceDownsample;
    }
    final sheet = SpriteSheet(
      image: image,
      srcSize: Vector2(srcW, srcH),
    );

    animations = {
      CreatureAnim.idle: sheet.createAnimation(
        row: animConfig.idleRow,
        from: 0,
        to: animConfig.idleFrames,
        stepTime: animConfig.idleStepTime,
      ),
      CreatureAnim.hop: sheet.createAnimation(
        row: animConfig.hopRow,
        from: 0,
        to: animConfig.hopFrames,
        stepTime: animConfig.hopStepTime,
        loop: false,
      ),
      CreatureAnim.hit: sheet.createAnimation(
        row: animConfig.hitRow,
        from: 0,
        to: animConfig.hitFrames,
        stepTime: animConfig.hitStepTime,
        loop: false,
      ),
      CreatureAnim.death: sheet.createAnimation(
        row: animConfig.deathRow,
        from: 0,
        to: animConfig.deathFrames,
        stepTime: animConfig.deathStepTime,
        loop: false,
      ),
    };

    current = CreatureAnim.idle;
    size = Vector2(frameWidth, frameHeight) * spriteScale;

    paint = Paint()..filterQuality = FilterQuality.none;
    if (tintPalette.isNotEmpty) {
      final tint = tintPalette[rng.nextInt(tintPalette.length)];
      paint.colorFilter = ColorFilter.mode(tint, BlendMode.modulate);
    }

    // Await so behaviors that affect initial state (e.g. GroundAnchor
    // setting position.y) finish loading before Creature itself mounts.
    for (final config in behaviorConfigs) {
      await add(config.create());
    }
  }

  // -- API for behaviors --

  void playAnim(CreatureAnim anim, {VoidCallback? onComplete}) {
    current = anim;
    animationTicker!
      ..reset()
      ..onComplete = onComplete;
  }

  void setFlip(bool facingLeft) {
    if (isFlippedHorizontally != facingLeft) flipHorizontally();
  }

  void moveWorldX(double delta) {
    worldX += delta;
  }

  /// Nearest-neighbor downsample an image by an integer factor. Used to
  /// intentionally reduce the effective source resolution of a sheet so
  /// the art reads chunkier at the final render scale.
  Future<Image> _decimate(Image src, int factor) async {
    final w = src.width ~/ factor;
    final h = src.height ~/ factor;
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..filterQuality = FilterQuality.none;
    canvas.drawImageRect(
      src,
      Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      paint,
    );
    return recorder.endRecording().toImage(w, h);
  }
}
