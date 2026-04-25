import '../lexaway_game.dart';

enum BiomeType { grassland, tropics, winter }

enum ItemCategory { entity, coin, creature }

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

class PierZone {
  final int startTile;
  final int endTile;

  const PierZone({required this.startTile, required this.endTile});

  int get widthTiles => endTile - startTile;
}

class WorldSegment {
  final BiomeType biome;
  final int startTile;
  final int endTile;
  final List<PlacedItem> items;
  final List<PierZone> pierZones;

  const WorldSegment({
    required this.biome,
    required this.startTile,
    required this.endTile,
    required this.items,
    this.pierZones = const [],
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

  /// Returns the pier zone at the given tile coordinate, or null.
  PierZone? pierZoneAt(int tileX) {
    for (final seg in segments) {
      if (tileX < seg.endTile) {
        for (final zone in seg.pierZones) {
          if (tileX >= zone.startTile && tileX < zone.endTile) return zone;
        }
        return null;
      }
    }
    return null;
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
