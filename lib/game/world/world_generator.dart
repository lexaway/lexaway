import 'dart:math';

import '../lexaway_game.dart';
import 'biome_definition.dart';
import 'biome_registry.dart';
import 'world_map.dart';

class WorldGenerator {
  static const int _minSegmentTiles = 30;
  static const int _maxSegmentTiles = 80;
  static const double _tilePx = 16.0 * LexawayGame.pixelScale;

  /// Generates a world of approximately [totalTiles] tiles from [seed].
  ///
  /// If [startTile] and [startIndex] are provided, the world starts from that
  /// point (used for lazy extensions).
  WorldMap generate(
    int seed, {
    int totalTiles = 3000,
    int startTile = 0,
    int startIndex = 0,
  }) {
    final rng = Random(seed);
    final segments = <WorldSegment>[];
    var tile = startTile;
    var itemIndex = startIndex;
    final endTile = startTile + totalTiles;

    while (tile < endTile) {
      final segLen = _minSegmentTiles +
          rng.nextInt(_maxSegmentTiles - _minSegmentTiles + 1);
      final segEnd = min(tile + segLen, endTile);
      final biome = _pickBiome(rng);
      final def = BiomeRegistry.get(biome);

      final items = <PlacedItem>[];

      // Entity placement via 1D Poisson disk sampling
      final entityPositions = _poissonDisk(
        rng,
        startPx: tile * _tilePx,
        endPx: segEnd * _tilePx,
        minGapPx: def.minEntityGapTiles * _tilePx,
        maxGapPx: def.maxEntityGapTiles * _tilePx,
      );

      for (final x in entityPositions) {
        items.add(PlacedItem(
          name: _pickWeightedEntity(rng, def),
          category: ItemCategory.entity,
          worldX: x,
          index: itemIndex++,
        ));
      }

      // Coin placement in gaps between entities
      final coinPositions = _placeCoinsBetweenEntities(
        rng,
        entityPositions: entityPositions,
        startPx: tile * _tilePx,
        endPx: segEnd * _tilePx,
        def: def,
      );

      for (final cp in coinPositions) {
        items.add(PlacedItem(
          name: cp.name,
          category: ItemCategory.coin,
          worldX: cp.worldX,
          index: itemIndex++,
        ));
      }

      items.sort((a, b) => a.worldX.compareTo(b.worldX));

      segments.add(WorldSegment(
        biome: biome,
        startTile: tile,
        endTile: segEnd,
        items: items,
      ));

      tile = segEnd;
    }

    return WorldMap(
      seed: seed,
      segments: segments,
      nextItemIndex: itemIndex,
    );
  }

  BiomeType _pickBiome(Random rng) {
    // Phase 1: always grassland.
    // Future: weighted selection with transition rules.
    return BiomeType.grassland;
  }

  /// 1D Poisson disk sampling: places points with at least [minGapPx] between
  /// them, with gaps varying up to [maxGapPx].
  List<double> _poissonDisk(
    Random rng, {
    required double startPx,
    required double endPx,
    required double minGapPx,
    required double maxGapPx,
  }) {
    final positions = <double>[];
    // Start with a random offset into the segment so entities don't always
    // begin at the segment boundary.
    var x = startPx + minGapPx * (0.5 + rng.nextDouble() * 0.5);

    while (x < endPx - minGapPx * 0.5) {
      positions.add(x);
      // Next position: at least minGapPx away, up to maxGapPx.
      x += minGapPx + rng.nextDouble() * (maxGapPx - minGapPx);
    }

    return positions;
  }

  String _pickWeightedEntity(Random rng, BiomeDefinition def) {
    var roll = rng.nextInt(def.totalEntityWeight);
    for (final w in def.entityWeights) {
      roll -= w.weight;
      if (roll < 0) return w.name;
    }
    return def.entityWeights.last.name;
  }

  /// Places coins in gaps between entities within a segment.
  List<_CoinPlacement> _placeCoinsBetweenEntities(
    Random rng, {
    required List<double> entityPositions,
    required double startPx,
    required double endPx,
    required BiomeDefinition def,
  }) {
    final coins = <_CoinPlacement>[];
    final minGapPx = def.minCoinGapTiles * _tilePx;
    final maxGapPx = def.maxCoinGapTiles * _tilePx;

    // Build list of gaps: before first entity, between entities, after last.
    final gaps = <_Gap>[];
    if (entityPositions.isEmpty) {
      gaps.add(_Gap(startPx, endPx));
    } else {
      gaps.add(_Gap(startPx, entityPositions.first));
      for (var i = 0; i < entityPositions.length - 1; i++) {
        gaps.add(_Gap(entityPositions[i], entityPositions[i + 1]));
      }
      gaps.add(_Gap(entityPositions.last, endPx));
    }

    // Place coins within each gap using similar Poisson approach
    for (final gap in gaps) {
      // Need at least a tile of buffer around entities
      final gapStart = gap.start + _tilePx;
      final gapEnd = gap.end - _tilePx;
      if (gapEnd - gapStart < minGapPx) continue;

      var x = gapStart + rng.nextDouble() * minGapPx * 0.5;
      while (x < gapEnd) {
        final roll = rng.nextDouble();
        if (roll < def.diamondChance) {
          coins.add(_CoinPlacement('diamond', x));
        } else if (roll < def.clusterChance) {
          coins.add(_CoinPlacement('coin', x));
          if (x + _tilePx < gapEnd) {
            coins.add(_CoinPlacement('coin', x + _tilePx));
          }
        } else {
          coins.add(_CoinPlacement('coin', x));
        }
        x += minGapPx + rng.nextDouble() * (maxGapPx - minGapPx);
      }
    }

    return coins;
  }
}

class _CoinPlacement {
  final String name;
  final double worldX;

  _CoinPlacement(this.name, this.worldX);
}

class _Gap {
  final double start;
  final double end;

  _Gap(this.start, this.end);
}
