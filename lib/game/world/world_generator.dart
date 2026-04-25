import 'dart:math';

import '../lexaway_game.dart';
import 'biome_definition.dart';
import 'biome_registry.dart';
import 'entity_footprints.dart';
import 'noise.dart';
import 'world_map.dart';

class WorldGenerator {
  static const int _minSegmentTiles = 30;
  static const int _maxSegmentTiles = 80;
  static const double _tilePx = 16.0 * LexawayGame.pixelScale;

  /// Buffer applied to every collision check — entities keep at least this
  /// many tiles of breathing room so sprites don't visually kiss.
  static const int _bufferTiles = 1;

  /// widthTiles for every placeable entity, per biome. Drives size-aware
  /// collision — a 3-tile palm tree needs more room than a 1-tile flower.
  final EntityFootprints entityFootprints;

  WorldGenerator({this.entityFootprints = const {}});

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

    // Per-region walker state, shared across every segment in this generate()
    // call so region spacing stays coherent in world coordinates across seams.
    // Keyed by RegionFeature identity (const instances in the biome registry).
    final regionWalkers = <RegionFeature, _RegionWalker>{};

    while (tile < endTile) {
      final segLen = _minSegmentTiles +
          rng.nextInt(_maxSegmentTiles - _minSegmentTiles + 1);
      final segEnd = min(tile + segLen, endTile);
      final biome = _pickBiome(rng);
      final def = BiomeRegistry.get(biome);

      // Shared collision pool for this segment. Scatters check against
      // everything already here; region children are appended as we go.
      final placements = <_Placement>[];
      // Region footprints placed in this segment. Exclusive footprints block
      // later scatters and creatures; non-exclusive ones only block other
      // regions.
      final footprints = <_Footprint>[];
      final pierZones = <PierZone>[];

      // Phase 1: place regions first, in declaration order.
      for (final feature in def.features.whereType<RegionFeature>()) {
        final walker = regionWalkers.putIfAbsent(
          feature,
          () => _RegionWalker(feature, seed, startTile),
        );
        walker.advanceTo(tile);

        while (walker.startTile < segEnd) {
          final candStart = walker.startTile;
          final candEnd = candStart + walker.width;

          // Only claim regions fully within the current segment — a candidate
          // straddling the seam is dropped here and its next-segment twin
          // (driven by the same walker) gets a chance instead.
          if (candStart < tile || candEnd > segEnd) {
            walker.advance();
            continue;
          }

          if (_overlapsAnyFootprint(candStart, candEnd, footprints)) {
            walker.advance();
            continue;
          }

          footprints.add(_Footprint(
            startTile: candStart,
            endTile: candEnd,
            exclusive: feature.exclusive,
          ));

          if (feature.exclusive && feature.kind == 'pier') {
            pierZones.add(
              PierZone(startTile: candStart, endTile: candEnd),
            );
          }

          _layOutChildren(
            feature: feature,
            startPx: candStart * _tilePx,
            endPx: candEnd * _tilePx,
            biome: biome,
            rng: walker.rng,
            placements: placements,
          );

          walker.advance();
        }
      }

      // Phase 2: scatters fill the gaps around regions.
      for (final feature in def.features.whereType<ScatterFeature>()) {
        final noise = Noise1D(seed + feature.noiseSeedOffset);
        final positions = _noisePoissonDisk(
          rng,
          noise: noise,
          feature: feature,
          startPx: tile * _tilePx,
          endPx: segEnd * _tilePx,
        );
        final widthTiles =
            entityFootprints[biome]?[feature.entityName] ?? 1;
        for (final x in positions) {
          if (_overlapsExclusiveFootprint(x, widthTiles, footprints)) {
            continue;
          }
          if (_collides(x, feature.entityName, biome, placements)) continue;
          placements.add(_Placement(feature.entityName, x));
        }
      }

      placements.sort((a, b) => a.worldX.compareTo(b.worldX));

      final items = <PlacedItem>[];
      final entityPositions = <double>[];
      for (final p in placements) {
        entityPositions.add(p.worldX);
        items.add(PlacedItem(
          name: p.name,
          category: ItemCategory.entity,
          worldX: p.worldX,
          index: itemIndex++,
        ));
      }

      // Coins placed in gaps between entities (unchanged).
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

      // Ambient creatures — independent of entity/coin slots. Still respect
      // exclusive footprints so a bunny doesn't stand on a pier.
      if (def.totalCreatureWeight > 0) {
        final creaturePositions = _poissonDisk(
          rng,
          startPx: tile * _tilePx,
          endPx: segEnd * _tilePx,
          minGapPx: def.minCreatureGapTiles * _tilePx,
          maxGapPx: def.maxCreatureGapTiles * _tilePx,
        );
        for (final x in creaturePositions) {
          if (_overlapsExclusiveFootprint(x, 1, footprints)) continue;
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
    final r = rng.nextDouble();
    if (r < 0.5) return BiomeType.grassland;
    if (r < 0.75) return BiomeType.tropics;
    return BiomeType.winter;
  }

  /// Lay out a region's children inside its footprint.
  ///
  /// `allowChildOverlap: true` → weighted-pick-and-stride; flowers of
  /// different colors interleave at adjacent tiles with no size check.
  /// `allowChildOverlap: false` → sequential per-child passes with
  /// size-aware collision against prior placements.
  void _layOutChildren({
    required RegionFeature feature,
    required double startPx,
    required double endPx,
    required BiomeType biome,
    required Random rng,
    required List<_Placement> placements,
  }) {
    if (feature.children.isEmpty) return;

    if (feature.allowChildOverlap) {
      final totalWeight =
          feature.children.fold<double>(0, (s, c) => s + c.weight);
      if (totalWeight <= 0) return;

      // Inner noise gives each meadow its own bumpy density field, so some
      // stretches are clumpy and some are sparse rather than every flower
      // sitting on a uniform grid. Seed it from the walker RNG so each placed
      // region gets a distinct pattern.
      final innerNoise = Noise1D(rng.nextInt(0x7FFFFFFF));
      const innerNoiseScale = 0.025;
      // Edge feather width — flowers thin out within this many pixels of the
      // meadow edges, so patches fade instead of ending hard.
      final feather = _tilePx * 3;

      var x = startPx;
      while (x < endPx) {
        final n = innerNoise.sample(x, scale: innerNoiseScale);
        final distFromEdge = min(x - startPx, endPx - x);
        final edgeFactor = (distFromEdge / feather).clamp(0.0, 1.0);
        final density = n * edgeFactor;

        // Emit gate — low-density spots get skipped entirely, creating real
        // gaps between clumps instead of evenly-spaced flowers.
        if (density > 0.25 && rng.nextDouble() < density * 1.2) {
          final child =
              _pickWeightedChild(rng, feature.children, totalWeight);
          placements.add(_Placement(
            child.entityName,
            x + (rng.nextDouble() - 0.5) * _tilePx * 0.6,
          ));
        }

        // Stride scales inversely with density: dense spots → ~0.7 tiles
        // between candidates (flowers land on consecutive tiles), sparse
        // spots → ~2.5 tiles, leaving visible gaps. Extra jitter breaks up
        // any remaining regularity.
        final densityFactor = 1.0 - density;
        final gapPx = _tilePx * (0.6 + densityFactor * 1.8);
        x += gapPx + rng.nextDouble() * _tilePx * 0.4;
      }
      return;
    }

    for (final child in feature.children) {
      var x = startPx + rng.nextDouble() * child.minGapTiles * _tilePx * 0.5;
      while (x < endPx) {
        if (!_collides(x, child.entityName, biome, placements)) {
          placements.add(_Placement(child.entityName, x));
        }
        x += child.minGapTiles * _tilePx;
      }
    }
  }

  RegionChild _pickWeightedChild(
    Random rng,
    List<RegionChild> children,
    double totalWeight,
  ) {
    var roll = rng.nextDouble() * totalWeight;
    for (final c in children) {
      roll -= c.weight;
      if (roll <= 0) return c;
    }
    return children.last;
  }

  /// Size-aware gap between two entities. Half-extents + breathing buffer.
  double _requiredGapPx(String nameA, String nameB, BiomeType biome) {
    final widthA = entityFootprints[biome]?[nameA] ?? 1;
    final widthB = entityFootprints[biome]?[nameB] ?? 1;
    return (widthA + widthB + 2 * _bufferTiles) * _tilePx * 0.5;
  }

  /// True if placing [name] at [worldX] would visually overlap any prior
  /// placement in [placements].
  bool _collides(
    double worldX,
    String name,
    BiomeType biome,
    List<_Placement> placements,
  ) {
    for (final p in placements) {
      final gap = (worldX - p.worldX).abs();
      if (gap < _requiredGapPx(name, p.name, biome)) return true;
    }
    return false;
  }

  /// True if the tile span [startTile..endTile] overlaps any existing
  /// footprint (plus 1-tile buffer). Used for region-vs-region collision.
  bool _overlapsAnyFootprint(
    int startTile,
    int endTile,
    List<_Footprint> footprints,
  ) {
    for (final f in footprints) {
      if (startTile < f.endTile + _bufferTiles &&
          endTile > f.startTile - _bufferTiles) {
        return true;
      }
    }
    return false;
  }

  /// True if an entity with top-left at [worldX] and width [widthTiles]
  /// would overlap any EXCLUSIVE footprint (plus 1-tile buffer). Used to
  /// keep scatters and creatures out of piers; non-exclusive regions
  /// (meadows) don't block scatters.
  bool _overlapsExclusiveFootprint(
    double worldX,
    int widthTiles,
    List<_Footprint> footprints,
  ) {
    if (footprints.isEmpty) return false;
    const buffer = _bufferTiles;
    final entityStart = worldX;
    final entityEnd = worldX + widthTiles * _tilePx;
    for (final f in footprints) {
      if (!f.exclusive) continue;
      final zoneStart = (f.startTile - buffer) * _tilePx;
      final zoneEnd = (f.endTile + buffer) * _tilePx;
      if (entityEnd > zoneStart && entityStart < zoneEnd) return true;
    }
    return false;
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

  /// Noise-modulated 1D Poisson disk for a single [ScatterFeature].
  ///
  /// The noise value at each candidate position controls two things:
  ///  1. Whether to spawn at all (must exceed [ScatterFeature.threshold]).
  ///  2. The gap to the next candidate — high noise shrinks gaps (denser),
  ///     low noise stretches them (sparser).
  List<double> _noisePoissonDisk(
    Random rng, {
    required Noise1D noise,
    required ScatterFeature feature,
    required double startPx,
    required double endPx,
  }) {
    final minGapPx = feature.minGapTiles * _tilePx;
    final maxGapPx = feature.maxGapTiles * _tilePx;
    final positions = <double>[];

    var x = startPx + minGapPx * (0.5 + rng.nextDouble() * 0.5);

    while (x < endPx - minGapPx * 0.5) {
      final n = noise.sample(x, scale: feature.noiseScale);
      if (n > feature.threshold) positions.add(x);
      // Noise modulates gap: high noise → small gap, low noise → big gap.
      // Walk continues below threshold so spacing stays spatially coherent.
      final densityFactor = 1.0 - n;
      final gap = minGapPx + densityFactor * (maxGapPx - minGapPx);
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

    for (final gap in gaps) {
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
}

/// Per-RegionFeature walker. Produces a deterministic sequence of candidate
/// `(startTile, width)` pairs anchored in world coordinates, so adjacent
/// segments of the same biome don't double-place or tile-align against each
/// other at seams. State lives for the duration of one `generate()` call.
///
/// Walkers are keyed by `RegionFeature` identity, and the biome registry
/// declares each feature const, so grassland and tropics get distinct walkers
/// even when both declare a `flower_meadow`. A walker only advances during
/// segments of its owning biome; other biomes' segments are skipped over
/// lazily by `advanceTo` on the next visit, which means a pier walker's
/// spacing is coherent across all tropics segments but undefined across the
/// grassland stretches between them — that's intentional.
class _RegionWalker {
  final RegionFeature feature;
  final Random rng;
  int startTile;
  int width;

  _RegionWalker(this.feature, int seed, int baseTile)
      : rng = Random(seed ^ feature.noiseSeedOffset ^ 0xABCDEF),
        startTile = 0,
        width = 0 {
    startTile = baseTile +
        rng.nextInt(_spacingRange() + 1); // initial offset inside spacing
    width = _pickWidth();
  }

  int _spacingRange() =>
      feature.maxSpacingTiles - feature.minSpacingTiles;

  int _pickWidth() =>
      feature.minWidthTiles +
      rng.nextInt(feature.maxWidthTiles - feature.minWidthTiles + 1);

  /// Advance past the current pending candidate to the next.
  void advance() {
    startTile +=
        width + feature.minSpacingTiles + rng.nextInt(_spacingRange() + 1);
    width = _pickWidth();
  }

  /// Skip candidates whose end would land before [targetTile]. Ensures a
  /// walker that stopped mid-world (e.g. because a previous segment of a
  /// different biome absorbed a stretch of world) catches back up.
  void advanceTo(int targetTile) {
    while (startTile + width <= targetTile) {
      advance();
    }
  }
}

class _Placement {
  final String name;
  final double worldX;

  _Placement(this.name, this.worldX);
}

class _Footprint {
  final int startTile;
  final int endTile;
  final bool exclusive;

  _Footprint({
    required this.startTile,
    required this.endTile,
    required this.exclusive,
  });
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
