import 'dart:async';

import 'package:flame/components.dart';

import '../components/biome_parallax.dart';
import '../components/camera.dart';
import '../events.dart';
import '../lexaway_game.dart';
import '../walk_state.dart';
import '../world/world_map.dart';

/// Owns anything that scrolls: parallax velocity, camera scroll speed, and
/// gentle cloud drift. Subscribes to walk events and translates them into
/// parallax base-velocity + camera scroll-speed changes.
///
/// Also detects biome boundaries and triggers parallax crossfades via
/// [BiomeParallax.transitionTo].
class ScrollController extends Component with HasGameReference<LexawayGame> {
  StreamSubscription<GameEvent>? _sub;

  final Camera _camera;
  final BiomeParallax _biomeParallax;
  final WorldMap _worldMap;
  final GameEvents _events;

  late BiomeType _currentBiome;

  ScrollController({
    required Camera camera,
    required BiomeParallax biomeParallax,
    required WorldMap worldMap,
    required GameEvents events,
  })  : _camera = camera,
        _biomeParallax = biomeParallax,
        _worldMap = worldMap,
        _events = events;

  @override
  void onMount() {
    super.onMount();
    _currentBiome = _worldMap.biomeAt(
      _camera.scrollOffset + game.size.x / 2,
    );
    _sub = _events.on<GameEvent>().listen(_handle);
  }

  void _handle(GameEvent event) {
    switch (event) {
      case WalkStarted(:final running):
        _applySpeed(running: running);
      case WalkSpeedChanged(:final running):
        _applySpeed(running: running);
      case WalkStopped(:final skipDistance):
        if (skipDistance > 0) _camera.scrollOffset += skipDistance;
        _biomeParallax.setBaseVelocity(Vector2.zero());
        _camera.scrollSpeed = 0;
      default:
        break;
    }
  }

  void _applySpeed({required bool running}) {
    final speed = running
        ? LexawayGame.walkSpeed * WalkState.runSpeedMultiplier
        : LexawayGame.walkSpeed;
    _biomeParallax.setBaseVelocity(Vector2(speed * 0.1, 0));
    _camera.scrollSpeed = speed;
  }

  @override
  void update(double dt) {
    _biomeParallax.applyCloudDrift(dt);

    // Detect biome boundary crossings at screen centre.
    final biome = _worldMap.biomeAt(
      _camera.scrollOffset + game.size.x / 2,
    );
    if (biome != _currentBiome) {
      final previous = _currentBiome;
      _currentBiome = biome;
      _biomeParallax.transitionTo(biome);
      _events.emit(BiomeChanged(previous: previous, current: biome));
    }
  }

  @override
  void onRemove() {
    _sub?.cancel();
    super.onRemove();
  }
}
