import 'dart:async';

import 'package:flame/components.dart';

import '../components/ground.dart';
import '../events.dart';
import '../lexaway_game.dart';
import '../walk_state.dart';

/// Owns anything that scrolls: parallax velocity, ground scroll speed, and
/// gentle cloud drift. Subscribes to walk events and translates them into
/// `ParallaxComponent.baseVelocity` + ground scroll speed changes.
class ScrollController extends Component with HasGameReference<LexawayGame> {
  StreamSubscription<GameEvent>? _sub;

  // Cached refs captured in onMount — avoids going through `game.*`
  // every frame for cloud drift.
  late final ParallaxComponent _parallax;
  late final Ground _ground;

  @override
  void onMount() {
    super.onMount();
    _parallax = game.parallaxComponent;
    _ground = game.ground;
    _sub = game.events.on<GameEvent>().listen(_handle);
  }

  void _handle(GameEvent event) {
    switch (event) {
      case WalkStarted(:final running):
        _applySpeed(running: running);
      case WalkSpeedChanged(:final running):
        _applySpeed(running: running);
      case WalkStopped(:final skipDistance):
        if (skipDistance > 0) _ground.scrollOffset += skipDistance;
        _parallax.parallax!.baseVelocity = Vector2.zero();
        _ground.stopScrolling();
      default:
        break;
    }
  }

  void _applySpeed({required bool running}) {
    final speed = running
        ? LexawayGame.walkSpeed * WalkState.runSpeedMultiplier
        : LexawayGame.walkSpeed;
    _parallax.parallax!.baseVelocity = Vector2(speed * 0.1, 0);
    _ground.startScrolling(speed);
  }

  @override
  void update(double dt) {
    // Gentle cloud drift independent of player movement. Moved out of
    // `LexawayGame.update` so all scrolling behavior lives in one place.
    //
    // Layers 1 and 2 are the back/front cloud layers. Guarded for biomes
    // that may ship with fewer than three parallax layers — drift just
    // no-ops in that case.
    final layers = _parallax.parallax!.layers;
    if (layers.length > 1) {
      layers[1].update(Vector2(LexawayGame.cloudDrift * dt, 0), dt);
    }
    if (layers.length > 2) {
      layers[2].update(Vector2(LexawayGame.cloudDrift * 1.8 * dt, 0), dt);
    }
  }

  @override
  void onRemove() {
    _sub?.cancel();
    super.onRemove();
  }
}
