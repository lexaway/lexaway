import 'package:flame/components.dart';

import '../events.dart';
import '../lexaway_game.dart';
import '../world/world_generator.dart';
import '../world/world_map.dart';

/// Owns lazy world extension. Watches the player's progress through the
/// [WorldMap] and, when the player gets within ~200 tiles of the end,
/// appends another 1000-tile chunk using a derived seed.
///
/// Pulled out of `LexawayGame.update` so the game loop doesn't have to know
/// about world generation. The extension counter lives here because it's
/// only meaningful alongside the extension logic — the seed formula is
/// `worldMap.seed + extensions`, so the two must stay in lockstep.
///
/// On boot, [LexawayGame] replays previously-persisted extensions by calling
/// [extend] in a loop before adding this component to the tree, which keeps
/// worldMap.segments consistent with the saved scroll offset.
class WorldStreamer extends Component with HasGameReference<LexawayGame> {
  /// How close (in tiles) to the end of the generated world before we
  /// trigger another extension.
  static const int _lookaheadTiles = 200;

  /// How many tiles to generate per extension batch.
  static const int _extensionTiles = 1000;

  final WorldMap worldMap;

  int _extensions = 0;

  WorldStreamer({required this.worldMap});

  /// How many extension batches have been appended so far. Read by the
  /// world-state snapshot so reboots can replay the same sequence.
  int get extensions => _extensions;

  /// Generate and append one more extension chunk. Emits [WorldExtended]
  /// once mounted so [WorldStatePersister] picks up the change.
  ///
  /// Safe to call during boot replay before the streamer is mounted:
  /// the event emit is skipped pre-mount, which is exactly what we want
  /// during replay (the on-disk state already reflects these segments).
  void extend() {
    _extensions++;
    final extensionSeed = worldMap.seed + _extensions;
    final extension = WorldGenerator().generate(
      extensionSeed,
      totalTiles: _extensionTiles,
      startTile: worldMap.totalTiles,
      startIndex: worldMap.nextItemIndex,
    );
    worldMap.segments.addAll(extension.segments);
    worldMap.nextItemIndex = extension.nextItemIndex;

    if (isMounted) {
      game.events.emit(const WorldExtended());
    }
  }

  @override
  void update(double dt) {
    final tilePx = 16.0 * LexawayGame.pixelScale;
    if (game.ground.scrollOffset + _lookaheadTiles * tilePx >
        worldMap.totalLengthPx) {
      extend();
    }
  }
}
