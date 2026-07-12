import 'dart:math';

import '../lexaway_game.dart';
import 'biome_definition.dart';
import 'biome_registry.dart';
import 'entity_footprints.dart';
import 'noise.dart';
import 'world_map.dart';

class WorldGenerator {
  static const int _minSegmentTiles = 90;
  static const int _maxSegmentTiles = 240;
  static const double _tilePx = 16.0 * LexawayGame.pixelScale;

  /// Buffer applied to every collision check — entities keep at least this
  /// many tiles of breathing room so sprites don't visually kiss.
  static const int _bufferTiles = 1;

  /// Claw machine cabinet footprint and spacing. Hardcoded here (rather than
  /// piped through entity manifests) since claw machines aren't a per-biome
  /// scatter — they're a global, sparse encounter category.
  static const int _clawMachineWidthTiles = 5;
  static const int _clawMachineMinGapTiles = 18;
  static const int _clawMachineMaxGapTiles = 36;

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
      final ctx = _SegmentContext(
        seed: seed,
        rng: rng,
        startTile: tile,
        endTile: segEnd,
        biome: _pickBiome(rng),
      );

      _placeRegions(ctx, regionWalkers, startTile);
      _placeGroups(ctx);
      _placeScatters(ctx);
      ctx.placements.sort((a, b) => a.worldX.compareTo(b.worldX));

      // Row order matters twice over: coins fill the gaps between the
      // (now sorted) entities, and the shared rng draws for coins and
      // creatures must happen in this sequence for a seed to keep
      // reproducing the same world.
      final rows = <_ItemRow>[
        for (final p in ctx.placements)
          (name: p.name, category: ItemCategory.entity, worldX: p.worldX),
        ..._coinRows(ctx),
        ..._clawMachineRows(ctx),
        ..._creatureRows(ctx),
      ];
      final items = [
        for (final r in rows)
          PlacedItem(
            name: r.name,
            category: r.category,
            worldX: r.worldX,
            index: itemIndex++,
          ),
      ]..sort((a, b) => a.worldX.compareTo(b.worldX));

      segments.add(WorldSegment(
        biome: ctx.biome,
        startTile: tile,
        endTile: segEnd,
        items: items,
        pierZones: ctx.pierZones,
      ));

      tile = segEnd;
    }

    return WorldMap(
      seed: seed,
      segments: segments,
      nextItemIndex: itemIndex,
    );
  }

  /// Phase 1: regions claim footprints first, in declaration order.
  /// [baseTile] is the generate() call's start tile, used to anchor
  /// newly-created walkers in world coordinates.
  void _placeRegions(
    _SegmentContext ctx,
    Map<RegionFeature, _RegionWalker> walkers,
    int baseTile,
  ) {
    for (final feature in ctx.def.features.whereType<RegionFeature>()) {
      final walker = walkers.putIfAbsent(
        feature,
        () => _RegionWalker(feature, ctx.seed, baseTile),
      );
      walker.advanceTo(ctx.startTile);

      while (walker.startTile < ctx.endTile) {
        final candStart = walker.startTile;
        final candEnd = candStart + walker.width;

        // Only claim regions fully within the current segment — a candidate
        // straddling the seam is dropped here and its next-segment twin
        // (driven by the same walker) gets a chance instead.
        if (candStart < ctx.startTile || candEnd > ctx.endTile) {
          walker.advance();
          continue;
        }

        if (_overlapsAnyFootprint(candStart, candEnd, ctx.footprints)) {
          walker.advance();
          continue;
        }

        ctx.footprints.add(_Footprint(
          startTile: candStart,
          endTile: candEnd,
          exclusive: feature.exclusive,
        ));

        if (feature.exclusive && feature.kind == 'pier') {
          ctx.pierZones.add(
            PierZone(startTile: candStart, endTile: candEnd),
          );
        }

        _layOutChildren(
          feature: feature,
          startPx: candStart * _tilePx,
          endPx: candEnd * _tilePx,
          biome: ctx.biome,
          rng: walker.rng,
          placements: ctx.placements,
        );

        walker.advance();
      }
    }
  }

  /// Phase 2: groups claim their cluster footprints next, before the
  /// scatters flood the segment. If we ran scatters first, dense filler
  /// (bushes, signs) would carpet the segment and almost any 4-6-tile
  /// cluster anchor would land on something — every group would abort.
  /// Running groups first means scatters' own collision checks naturally
  /// route around the rest areas instead.
  void _placeGroups(_SegmentContext ctx) {
    for (final feature in ctx.def.features.whereType<GroupFeature>()) {
      final groupRng = Random(ctx.seed + feature.noiseSeedOffset);
      final anchors = _poissonDisk(
        groupRng,
        startPx: ctx.startPx,
        endPx: ctx.endPx,
        minGapPx: feature.minGapTiles * _tilePx,
        maxGapPx: feature.maxGapTiles * _tilePx,
      );
      for (final anchorX in anchors) {
        _tryPlaceGroup(
          feature: feature,
          anchorX: anchorX,
          segEndPx: ctx.endPx,
          biome: ctx.biome,
          rng: groupRng,
          placements: ctx.placements,
          footprints: ctx.footprints,
        );
      }
    }
  }

  /// Phase 3: scatters fill the gaps around regions and groups.
  void _placeScatters(_SegmentContext ctx) {
    for (final feature in ctx.def.features.whereType<ScatterFeature>()) {
      final noise = Noise1D(ctx.seed + feature.noiseSeedOffset);
      final positions = _noisePoissonDisk(
        ctx.rng,
        noise: noise,
        feature: feature,
        startPx: ctx.startPx,
        endPx: ctx.endPx,
      );
      final widthTiles =
          entityFootprints[ctx.biome]?[feature.entityName] ?? 1;
      for (final x in positions) {
        if (_overlapsExclusiveFootprint(x, widthTiles, ctx.footprints)) {
          continue;
        }
        if (_collides(x, feature.entityName, ctx.biome, ctx.placements)) {
          continue;
        }
        ctx.placements.add(_Placement(feature.entityName, x));
      }
    }
  }

  /// Coins placed in gaps between entities. Relies on ctx.placements being
  /// sorted by worldX before this runs.
  List<_ItemRow> _coinRows(_SegmentContext ctx) {
    final coins = _placeCoinsBetweenEntities(
      ctx.rng,
      entityPositions: [for (final p in ctx.placements) p.worldX],
      startPx: ctx.startPx,
      endPx: ctx.endPx,
      def: ctx.def,
    );
    return [
      for (final c in coins)
        (name: c.name, category: ItemCategory.coin, worldX: c.worldX),
    ];
  }

  /// Claw machine encounters — sparse, biome-agnostic. Placed before
  /// creatures so creatures route around them, and respecting exclusive
  /// footprints so a cabinet doesn't materialize on a pier.
  List<_ItemRow> _clawMachineRows(_SegmentContext ctx) {
    final clawMachineRng = Random(ctx.seed ^ 0xC1A47);
    final positions = _poissonDisk(
      clawMachineRng,
      startPx: ctx.startPx,
      endPx: ctx.endPx,
      minGapPx: _clawMachineMinGapTiles * _tilePx,
      maxGapPx: _clawMachineMaxGapTiles * _tilePx,
    );
    return [
      for (final x in positions)
        if (!_overlapsExclusiveFootprint(
              x,
              _clawMachineWidthTiles,
              ctx.footprints,
            ) &&
            !_collidesWithWidth(
              x,
              _clawMachineWidthTiles,
              ctx.biome,
              ctx.placements,
            ))
          (
            name: 'claw_machine',
            category: ItemCategory.clawMachine,
            worldX: x,
          ),
    ];
  }

  /// Ambient creatures — independent of entity/coin slots. Still respect
  /// exclusive footprints so a bunny doesn't stand on a pier.
  List<_ItemRow> _creatureRows(_SegmentContext ctx) {
    if (ctx.def.totalCreatureWeight <= 0) return const [];
    final positions = _poissonDisk(
      ctx.rng,
      startPx: ctx.startPx,
      endPx: ctx.endPx,
      minGapPx: ctx.def.minCreatureGapTiles * _tilePx,
      maxGapPx: ctx.def.maxCreatureGapTiles * _tilePx,
    );
    return [
      for (final x in positions)
        if (!_overlapsExclusiveFootprint(x, 1, ctx.footprints))
          (
            name: _pickWeightedCreature(ctx.rng, ctx.def),
            category: ItemCategory.creature,
            worldX: x,
          ),
    ];
  }

  BiomeType _pickBiome(Random rng) {
    final r = rng.nextDouble();
    if (r < 0.40) return BiomeType.grassland;
    if (r < 0.60) return BiomeType.tropics;
    if (r < 0.80) return BiomeType.winter;
    return BiomeType.autumn;
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

  /// Try to place every child of [feature] in a single shuffled cluster,
  /// starting at [anchorX]. Each child sits at the next collision-clear x to
  /// the right of the previous one. If any child can't fit (would collide
  /// with prior placements, an exclusive footprint, or run past
  /// [segEndPx]), the entire group is dropped — no partial rest areas.
  void _tryPlaceGroup({
    required GroupFeature feature,
    required double anchorX,
    required double segEndPx,
    required BiomeType biome,
    required Random rng,
    required List<_Placement> placements,
    required List<_Footprint> footprints,
  }) {
    final order = [...feature.children]..shuffle(rng);
    final pending = <_Placement>[];
    var x = anchorX;
    String? prevName;

    for (final name in order) {
      if (prevName != null) {
        x += _requiredGapPx(prevName, name, biome);
      }
      final widthTiles = entityFootprints[biome]?[name] ?? 1;
      if (x + widthTiles * _tilePx > segEndPx) return;
      if (_overlapsExclusiveFootprint(x, widthTiles, footprints)) return;
      if (_collides(x, name, biome, placements)) return;
      if (_collides(x, name, biome, pending)) return;
      pending.add(_Placement(name, x));
      prevName = name;
    }

    placements.addAll(pending);
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
    final widthTiles = entityFootprints[biome]?[name] ?? 1;
    return _collidesWithWidth(worldX, widthTiles, biome, placements);
  }

  /// Variant of [_collides] for placements whose width isn't in any biome's
  /// entity manifest — the caller passes the widthTiles directly. Used by
  /// claw machine placement, which lives outside the biome scatter system.
  bool _collidesWithWidth(
    double worldX,
    int widthTiles,
    BiomeType biome,
    List<_Placement> placements,
  ) {
    for (final p in placements) {
      final widthOther = entityFootprints[biome]?[p.name] ?? 1;
      final requiredGapPx =
          (widthTiles + widthOther + 2 * _bufferTiles) * _tilePx * 0.5;
      if ((worldX - p.worldX).abs() < requiredGapPx) return true;
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

/// A placed item before it gets its world-wide index — generate() stamps the
/// running index so numbering stays a single-owner concern.
typedef _ItemRow = ({String name, ItemCategory category, double worldX});

/// Working state for generating one segment: its identity (span, biome) plus
/// the shared pools the placement phases fill in turn.
class _SegmentContext {
  final int seed;

  /// The generate()-wide RNG. Draw order is part of the deterministic
  /// output, so phases must consume it strictly in call order.
  final Random rng;
  final int startTile;
  final int endTile;
  final BiomeType biome;
  final BiomeDefinition def;

  /// Shared collision pool for this segment. Scatters check against
  /// everything already here; region children are appended as we go.
  final placements = <_Placement>[];

  /// Region footprints placed in this segment. Exclusive footprints block
  /// later scatters and creatures; non-exclusive ones only block other
  /// regions.
  final footprints = <_Footprint>[];
  final pierZones = <PierZone>[];

  _SegmentContext({
    required this.seed,
    required this.rng,
    required this.startTile,
    required this.endTile,
    required this.biome,
  }) : def = BiomeRegistry.get(biome);

  double get startPx => startTile * WorldGenerator._tilePx;
  double get endPx => endTile * WorldGenerator._tilePx;
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
