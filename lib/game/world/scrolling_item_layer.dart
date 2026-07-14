import 'package:flame/components.dart';

import '../components/camera.dart';
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
/// Subclasses supply the item factory and can read [activeItems] for fast
/// lookups (e.g. to grab a coin's sprite state during its pickup handler).
abstract class ScrollingItemLayer<T extends ScrollingWorldItem>
    extends Component with HasGameReference<LexawayGame> {
  final WorldMap worldMap;
  final Camera camera;
  final ItemCategory category;

  /// Horizontal padding (px) added before/after the visible area — items
  /// inside this window are eligible for spawning, and items past the left
  /// edge minus [cullMarginPx] are removed.
  final double spawnMarginPx;
  final double cullMarginPx;

  /// Per-frame spawn cap. Used by coin spawning so a big catch-up after a
  /// long pause doesn't produce a frame spike.
  final int maxSpawnsPerFrame;

  /// When true, culled items are blacklisted from re-spawning for the
  /// session. Required for entities whose on-screen `worldX` mutates away
  /// from their static [PlacedItem.worldX] — otherwise the still-static
  /// PlacedItem re-enters the spawn window and a fresh copy pops in mid-view.
  final bool cullPermanent;

  /// Items currently on-screen, keyed by item index. Subclasses can read
  /// this directly for domain lookups (e.g. pickup handlers) but should
  /// not mutate it — the base class owns the lifecycle.
  final Map<int, T> activeItems = {};

  /// Indexes that should never re-spawn this session. Populated by the cull
  /// step (when [cullPermanent] is true) or directly via [markCulled].
  final Set<int> _culledIndices = {};

  ScrollingItemLayer({
    required this.worldMap,
    required this.camera,
    required this.category,
    this.spawnMarginPx = 64,
    this.cullMarginPx = 64,
    this.maxSpawnsPerFrame = 1 << 30,
    this.cullPermanent = false,
  });

  /// Build a T for the given world item. Return `null` to skip (e.g.
  /// already collected, missing sprite def for the biome).
  T? createItem(PlacedItem item);

  /// Whether to skip spawning an item with this index. Subclasses can
  /// override to suppress items that have already been consumed or fled.
  bool shouldSkip(int index) => false;

  /// Proactively blacklist [index] from future spawns — e.g. when a creature
  /// flees faster than the cull margin can catch up, or when a pickup is
  /// collected. Idempotent.
  void markCulled(int index) => _culledIndices.add(index);

  @override
  void update(double dt) {
    final offset = camera.scrollOffset;
    final startX = offset - spawnMarginPx;
    final endX = offset + game.size.x + spawnMarginPx;

    var spawned = 0;
    for (final item in worldMap.itemsInRange(startX, endX)) {
      if (item.category != category) continue;
      if (activeItems.containsKey(item.index)) continue;
      if (_culledIndices.contains(item.index)) continue;
      if (shouldSkip(item.index)) continue;
      if (spawned >= maxSpawnsPerFrame) break;

      final built = createItem(item);
      if (built == null) continue;

      activeItems[item.index] = built;
      add(built);
      spawned++;
    }

    // Two-pass to avoid mutating activeItems mid-iteration. Order is
    // irrelevant — Flame draws by priority and position updates are
    // independent.
    final toRemove = <int>[];
    final viewportRight = game.size.x;
    // Right-edge cull uses spawnMarginPx (not cullMarginPx) so items freshly
    // spawned in the right window aren't instantly removed; the left edge can
    // stay tight since items only reach it after passing through view.
    for (final entry in activeItems.entries) {
      final item = entry.value;
      item.position.x = item.worldX - offset;
      final offLeft = item.position.x + item.layerWidth < -cullMarginPx;
      final offRight = item.position.x > viewportRight + spawnMarginPx;
      if (offLeft || offRight) {
        toRemove.add(entry.key);
      }
    }
    for (final index in toRemove) {
      activeItems.remove(index)?.removeFromParent();
      if (cullPermanent) _culledIndices.add(index);
    }
  }
}
