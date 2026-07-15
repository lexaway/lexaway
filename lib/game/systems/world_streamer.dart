import 'package:flame/components.dart';

import '../components/world_camera.dart';
import '../events.dart';
import '../lexaway_game.dart';
import '../world/entity_footprints.dart';
import '../world/world_generator.dart';
import '../world/world_map.dart';

/// Lazy world extension: when the player gets within [_lookaheadTiles] of the
/// end, appends another chunk using seed `worldMap.seed + extensions`. The
/// counter and seed must stay in lockstep.
///
/// On boot, [LexawayGame] replays persisted extensions by calling [extend] in
/// a loop before mounting this component, keeping worldMap.segments consistent
/// with the saved scroll offset.
class WorldStreamer extends Component {
  static const int _lookaheadTiles = 200;
  static const int _extensionTiles = 1000;

  final WorldMap worldMap;
  final EntityFootprints _entityFootprints;
  final WorldCamera _camera;
  final GameEvents _events;

  int _extensions = 0;

  WorldStreamer({
    required this.worldMap,
    required WorldCamera camera,
    required GameEvents events,
    EntityFootprints entityFootprints = const {},
  })  : _camera = camera,
        _events = events,
        _entityFootprints = entityFootprints;

  /// Extension batches appended so far. Read by the world-state snapshot so
  /// reboots can replay the same sequence.
  int get extensions => _extensions;

  /// Generate and append one more extension chunk. Emits [WorldExtended] only
  /// once mounted, so boot replay (already reflected on disk) skips the emit.
  void extend() {
    _extensions++;
    final extensionSeed = worldMap.seed + _extensions;
    final extension = WorldGenerator(entityFootprints: _entityFootprints)
        .generate(
      extensionSeed,
      totalTiles: _extensionTiles,
      startTile: worldMap.totalTiles,
      startIndex: worldMap.nextItemIndex,
    );
    worldMap.segments.addAll(extension.segments);
    worldMap.nextItemIndex = extension.nextItemIndex;

    if (isMounted) {
      _events.emit(const WorldExtended());
    }
  }

  @override
  void update(double dt) {
    final tilePx = 16.0 * LexawayGame.pixelScale;
    if (_camera.scrollOffset + _lookaheadTiles * tilePx >
        worldMap.totalLengthPx) {
      extend();
    }
  }
}
