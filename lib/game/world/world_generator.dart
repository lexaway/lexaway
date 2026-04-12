import 'dart:math';

import '../lexaway_game.dart';
import 'biome_definition.dart';
import 'biome_registry.dart';
import 'noise.dart';
import 'world_map.dart';

class WorldGenerator {
  static const int _minSegmentTiles = 30;
  static const int _maxSegmentTiles = 80;
  static const double _tilePx = 16.0 * LexawayGame.pixelScale;

  /// Minimum pixel distance between any two entities from different layers.
  /// Prevents visual overlaps when independent layers happen to land nearby.
  static const double _minCollisionPx = 6.0 * _tilePx;

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

      final pierZones = biome == BiomeType.tropics
          ? _generatePierZones(rng, tile, segEnd)
          : const <PierZone>[];

      final items = <PlacedItem>[];

      // Entity placement — each spawn layer runs its own noise-modulated
      // Poisson disk pass independently, then we merge and resolve collisions.
      final layerEntities = <_LayerPlacement>[];
      for (final layer in def.entityLayers) {
        final noise = Noise1D(seed + layer.noiseSeedOffset);
        final positions = _noisePoissonDisk(
          rng,
          noise: noise,
          layer: layer,
          startPx: tile * _tilePx,
          endPx: segEnd * _tilePx,
        );
        for (final x in positions) {
          if (_insidePierZone(x, pierZones)) continue;
          layerEntities.add(_LayerPlacement(layer.entityName, x));
        }
      }

      // Merge: sort by position, then cull any entity that's too close to a
      // previously accepted one. This naturally resolves overlaps between
      // layers while preserving each layer's noise-driven distribution.
      layerEntities.sort((a, b) => a.worldX.compareTo(b.worldX));
      final entityPositions = <double>[];
      for (final lp in layerEntities) {
        if (entityPositions.isNotEmpty &&
            (lp.worldX - entityPositions.last) < _minCollisionPx) {
          continue;
        }
        entityPositions.add(lp.worldX);
        items.add(PlacedItem(
          name: lp.name,
          category: ItemCategory.entity,
          worldX: lp.worldX,
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

      // Ambient creature placement — independent of entity/coin slots. A
      // bunny can stand in front of a bush or next to a coin and that's
      // fine; they're purely visual and much sparser than either.
      //
      // `totalCreatureWeight > 0` (rather than `isNotEmpty`) guards against
      // a biome that declares creatures but with all-zero weights —
      // `_pickWeightedCreature` uses `rng.nextInt(total)` which crashes on 0.
      if (def.totalCreatureWeight > 0) {
        final creaturePositions = _poissonDisk(
          rng,
          startPx: tile * _tilePx,
          endPx: segEnd * _tilePx,
          minGapPx: def.minCreatureGapTiles * _tilePx,
          maxGapPx: def.maxCreatureGapTiles * _tilePx,
        );

        for (final x in creaturePositions) {
          if (_insidePierZone(x, pierZones)) continue;
          items.add(PlacedItem(
            name: _pickWeightedCreature(rng, def),
            category: ItemCategory.creature,
            worldX: x,
            index: itemIndex++,
          ));
        }
      }

      items.sort((a, b) => a.worldX.compareTo(b.worldX));

      segments.add(WorldSegment(
        biome: biome,
        startTile: tile,
        endTile: segEnd,
        items: items,
        pierZones: pierZones,
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
    return rng.nextDouble() < 0.6 ? BiomeType.grassland : BiomeType.tropics;
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
    var x = startPx + minGapPx * (0.5 + rng.nextDouble() * 0.5);

    while (x < endPx - minGapPx * 0.5) {
      positions.add(x);
      x += minGapPx + rng.nextDouble() * (maxGapPx - minGapPx);
    }

    return positions;
  }

  /// Noise-modulated 1D Poisson disk for a single [SpawnLayer].
  ///
  /// The noise value at each candidate position controls two things:
  ///  1. Whether to spawn at all (must exceed [layer.threshold]).
  ///  2. The gap to the next candidate — high noise shrinks gaps (denser),
  ///     low noise stretches them (sparser).
  List<double> _noisePoissonDisk(
    Random rng, {
    required Noise1D noise,
    required SpawnLayer layer,
    required double startPx,
    required double endPx,
  }) {
    final minGapPx = layer.minGapTiles * _tilePx;
    final maxGapPx = layer.maxGapTiles * _tilePx;
    final positions = <double>[];

    var x = startPx + minGapPx * (0.5 + rng.nextDouble() * 0.5);

    while (x < endPx - minGapPx * 0.5) {
      final n = noise.sample(x, scale: layer.noiseScale);

      if (n > layer.threshold) {
        positions.add(x);
      }

      // Noise modulates gap: high noise → small gap, low noise → big gap.
      // Even when below threshold (no spawn), the walk continues so the noise
      // pattern stays spatially coherent.
      final densityFactor = 1.0 - n; // 0 when noise=1, 1 when noise=0
      final gap = minGapPx + densityFactor * (maxGapPx - minGapPx);
      // Add a little jitter so positions aren't perfectly grid-locked.
      x += gap + rng.nextDouble() * minGapPx * 0.3;
    }

    return positions;
  }

  String _pickWeightedCreature(Random rng, BiomeDefinition def) {
    var roll = rng.nextInt(def.totalCreatureWeight);
    for (final w in def.creatureWeights) {
      roll -= w.weight;
      if (roll < 0) return w.name;
    }
    return def.creatureWeights.last.name;
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
        } else if (roll < def.diamondChance + def.clusterChance) {
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

  /// Generates 0–2 pier zones within a tropics segment.
  List<PierZone> _generatePierZones(Random rng, int segStart, int segEnd) {
    const minWidth = 5;
    const maxWidth = 12;
    const edgePadding = 3;
    const minGap = 15;

    final available = segEnd - segStart - edgePadding * 2;
    if (available < minWidth) return const [];

    // Decide how many piers: 0 (30%), 1 (50%), 2 (20%).
    final roll = rng.nextDouble();
    final count = roll < 0.3 ? 0 : roll < 0.8 ? 1 : 2;
    if (count == 0) return const [];

    final zones = <PierZone>[];
    for (var i = 0; i < count; i++) {
      final width = minWidth + rng.nextInt(maxWidth - minWidth + 1);

      // Find a valid start position.
      final earliest = zones.isEmpty
          ? segStart + edgePadding
          : zones.last.endTile + minGap;
      final latest = segEnd - edgePadding - width;
      if (earliest > latest) break;

      final start = earliest + rng.nextInt(latest - earliest + 1);
      zones.add(PierZone(startTile: start, endTile: start + width));
    }

    return zones;
  }

  /// Returns true if [worldX] (in pixels) falls inside any pier zone (±1 tile
  /// buffer so entities don't visually overlap pier posts).
  bool _insidePierZone(double worldX, List<PierZone> zones) {
    if (zones.isEmpty) return false;
    final buffer = _tilePx;
    for (final zone in zones) {
      final zoneStartPx = zone.startTile * _tilePx;
      final zoneEndPx = zone.endTile * _tilePx;
      if (worldX >= zoneStartPx - buffer && worldX <= zoneEndPx + buffer) {
        return true;
      }
    }
    return false;
  }
}

class _LayerPlacement {
  final String name;
  final double worldX;

  _LayerPlacement(this.name, this.worldX);
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
