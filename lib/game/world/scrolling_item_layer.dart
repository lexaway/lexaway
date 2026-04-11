import 'package:flame/components.dart';

import '../lexaway_game.dart';
import 'world_map.dart';

/// Marker mixin for components materialized by [ScrollingItemLayer].
/// Anything streamed from the [WorldMap] needs a stable world-space
/// coordinate and item index (for dedup/persistence), plus an on-screen
/// width used to decide when it's scrolled off the left edge.
mixin ScrollingWorldItem on PositionComponent {
  double get worldX;
  int get itemIndex;
  double get layerWidth;
}

/// Base class for components that materialize a category of items from the
/// pre-generated [WorldMap] as the player scrolls, and cull them as they
/// leave the viewport.
///
/// Extracted from what used to be parallel spawn/cull loops in
/// [CoinManager] and [WorldRenderer]. Subclasses supply the item factory
/// and can read [activeItems] for fast lookups (e.g. to grab a coin's
/// sprite state during its pickup handler).
abstract class ScrollingItemLayer<T extends ScrollingWorldItem>
    extends Component with HasGameReference<LexawayGame> {
  final WorldMap worldMap;
  final ItemCategory category;

  /// Horizontal padding (px) added before/after the visible area — items
  /// inside this window are eligible for spawning, and items past the left
  /// edge minus [cullMarginPx] are removed.
  final double spawnMarginPx;
  final double cullMarginPx;

  /// Per-frame spawn cap. Used by coin spawning so a big catch-up after a
  /// long pause doesn't produce a frame spike.
  final int maxSpawnsPerFrame;

  /// Items currently on-screen, keyed by item index. Subclasses can read
  /// this directly for domain lookups (e.g. pickup handlers) but should
  /// not mutate it — the base class owns the lifecycle.
  final Map<int, T> activeItems = {};

  ScrollingItemLayer({
    required this.worldMap,
    required this.category,
    this.spawnMarginPx = 64,
    this.cullMarginPx = 64,
    this.maxSpawnsPerFrame = 1 << 30,
  });

  /// Build a T for the given world item. Return `null` to skip (e.g.
  /// already collected, missing sprite def for the biome).
  T? createItem(PlacedItem item);

  @override
  void update(double dt) {
    final offset = game.ground.scrollOffset;
    final startX = offset - spawnMarginPx;
    final endX = offset + game.size.x + spawnMarginPx;

    var spawned = 0;
    for (final item in worldMap.itemsInRange(startX, endX)) {
      if (item.category != category) continue;
      if (activeItems.containsKey(item.index)) continue;
      if (spawned >= maxSpawnsPerFrame) break;

      final built = createItem(item);
      if (built == null) continue;

      activeItems[item.index] = built;
      add(built);
      spawned++;
    }

    // Position & cull. Two-pass to avoid mutating activeItems mid-iteration.
    // Order doesn't matter — Flame draws by component priority, not iteration
    // order, and position updates are independent per item.
    final toRemove = <int>[];
    for (final entry in activeItems.entries) {
      final item = entry.value;
      item.position.x = item.worldX - offset;
      if (item.position.x + item.layerWidth < -cullMarginPx) {
        toRemove.add(entry.key);
      }
    }
    for (final index in toRemove) {
      activeItems.remove(index)?.removeFromParent();
    }
  }
}
