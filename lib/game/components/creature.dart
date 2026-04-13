import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';

import '../lexaway_game.dart';
import '../world/biome_definition.dart';
import '../world/scrolling_item_layer.dart';

enum CreatureAnim { idle, hop, hit, death }

/// An ambient animated critter that rides world scroll. Unlike [Entity],
/// which renders a single static sprite, [Creature] runs a multi-row sprite
/// sheet with an idle loop and occasional one-shot hops.
///
/// Creatures idle until the player gets close, then flee in the opposite
/// direction (leftward) with a looping hop animation.
class Creature extends SpriteAnimationGroupComponent<CreatureAnim>
    with HasGameReference<LexawayGame>, ScrollingWorldItem {
  final String sheetPath;
  final double frameWidth;
  final double frameHeight;
  final double spriteScale;
  final CreatureBehavior behavior;

  @override
  double worldX;

  @override
  final int itemIndex;

  /// Per-creature RNG seeded from the unique world item index so each bunny
  /// hops on its own schedule instead of lock-stepping with its neighbors.
  final Random _rng;

  double _nextHopIn = 0;
  bool _playingHop = false;
  bool fleeing = false;

  /// How fast the creature flees leftward in world-space px/s.
  static const double _fleeSpeed = 260.0;

  /// Distance (in tiles) ahead of the player at which the creature bolts.
  static const double _fleeTriggerTiles = 2.0;
  static const double _fleeTriggerPx =
      _fleeTriggerTiles * 16 * LexawayGame.pixelScale;

  Creature({
    required this.sheetPath,
    required this.frameWidth,
    required this.frameHeight,
    required this.spriteScale,
    required this.behavior,
    required this.worldX,
    required this.itemIndex,
  }) : _rng = Random(itemIndex);

  @override
  double get layerWidth => size.x;

  @override
  Future<void> onLoad() async {
    final image = await game.images.load(sheetPath);
    final sheet = SpriteSheet(
      image: image,
      srcSize: Vector2(frameWidth, frameHeight),
    );

    animations = {
      CreatureAnim.idle: sheet.createAnimation(
        row: behavior.idleRow,
        from: 0,
        to: behavior.idleFrames,
        stepTime: behavior.idleStepTime,
      ),
      CreatureAnim.hop: sheet.createAnimation(
        row: behavior.hopRow,
        from: 0,
        to: behavior.hopFrames,
        stepTime: behavior.hopStepTime,
        loop: false,
      ),
      CreatureAnim.hit: sheet.createAnimation(
        row: behavior.hitRow,
        from: 0,
        to: behavior.hitFrames,
        stepTime: behavior.hitStepTime,
        loop: false,
      ),
      CreatureAnim.death: sheet.createAnimation(
        row: behavior.deathRow,
        from: 0,
        to: behavior.deathFrames,
        stepTime: behavior.deathStepTime,
        loop: false,
      ),
    };

    current = CreatureAnim.idle;
    size = Vector2(frameWidth, frameHeight) * spriteScale;

    final groundTop = game.size.y * LexawayGame.groundLevel;
    position.y = groundTop - size.y;

    paint = Paint()..filterQuality = FilterQuality.none;

    _nextHopIn = _rollHopInterval();
  }

  double _rollHopInterval() {
    final range = behavior.maxHopIntervalSec - behavior.minHopIntervalSec;
    return behavior.minHopIntervalSec + _rng.nextDouble() * range;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (fleeing) {
      worldX -= _fleeSpeed * dt;
      return;
    }

    // Check whether the player is close enough to spook us.
    final scrollOffset = game.ground.scrollOffset;
    final playerScreenX = game.size.x * 0.25;
    final myScreenX = worldX - scrollOffset;
    final gap = myScreenX - playerScreenX;
    if (gap > 0 && gap < _fleeTriggerPx) {
      _startFlee();
      return;
    }

    // Normal idle / occasional hop.
    if (_playingHop) return;

    _nextHopIn -= dt;
    if (_nextHopIn > 0) return;

    _playingHop = true;
    current = CreatureAnim.hop;
    animationTicker!
      ..reset()
      ..onComplete = () {
        _playingHop = false;
        current = CreatureAnim.idle;
        _nextHopIn = _rollHopInterval();
      };
  }

  void _startFlee() {
    fleeing = true;
    // flipHorizontally negates scale.x, which shifts rendering by the sprite
    // width. Compensate so the bunny doesn't visually teleport.
    worldX += size.x;
    flipHorizontally();
    _loopHop();
  }

  /// Keep the hop animation cycling for the duration of the flee.
  void _loopHop() {
    current = CreatureAnim.hop;
    animationTicker!
      ..reset()
      ..onComplete = () {
        if (fleeing && isMounted) _loopHop();
      };
  }
}
