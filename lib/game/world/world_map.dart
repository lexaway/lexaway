import '../lexaway_game.dart';

enum BiomeType { grassland }

enum ItemCategory { entity, coin }

class PlacedItem {
  final String name;
  final ItemCategory category;
  final double worldX;

  /// Unique index across the entire world, used for coin collection tracking.
  final int index;

  const PlacedItem({
    required this.name,
    required this.category,
    required this.worldX,
    required this.index,
  });
}

class WorldSegment {
  final BiomeType biome;
  final int startTile;
  final int endTile;
  final List<PlacedItem> items;

  const WorldSegment({
    required this.biome,
    required this.startTile,
    required this.endTile,
    required this.items,
  });

  double get startPx => startTile * 16.0 * LexawayGame.pixelScale;
  double get endPx => endTile * 16.0 * LexawayGame.pixelScale;
}

class WorldMap {
  final int seed;
  final List<WorldSegment> segments;

  /// Running count of items across all segments, used to assign unique indices
  /// when extending the world.
  int nextItemIndex;

  WorldMap({
    required this.seed,
    required this.segments,
    this.nextItemIndex = 0,
  });

  double get totalLengthPx {
    if (segments.isEmpty) return 0;
    return segments.last.endPx;
  }

  int get totalTiles {
    if (segments.isEmpty) return 0;
    return segments.last.endTile;
  }

  BiomeType biomeAt(double worldX) {
    for (final seg in segments) {
      if (worldX < seg.endPx) return seg.biome;
    }
    return segments.last.biome;
  }

  /// Returns all items whose worldX falls within [startX, endX].
  Iterable<PlacedItem> itemsInRange(double startX, double endX) sync* {
    for (final seg in segments) {
      if (seg.endPx < startX) continue;
      if (seg.startPx > endX) break;
      for (final item in seg.items) {
        if (item.worldX > endX) break;
        if (item.worldX >= startX) yield item;
      }
    }
  }
}
