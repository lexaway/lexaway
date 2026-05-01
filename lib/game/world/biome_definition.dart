import 'dart:ui';

import '../audio_manager.dart';
import '../components/behaviors/behavior_config.dart';
import 'weather_def.dart';
import 'world_map.dart';

class WeightedEntity {
  final String name;
  final int weight;

  const WeightedEntity(this.name, this.weight);
}

/// Base type for every world-generation feature. A feature is either a
/// `ScatterFeature` (flat noise-driven Poisson scatter across a segment) or
/// a `RegionFeature` (a contiguous span that claims a footprint and lays out
/// its own children).
sealed class Feature {
  const Feature();
}

/// Flat noise-modulated Poisson scatter across a whole segment. Each instance
/// runs its own independent pass; placements are merged with size-aware
/// collision against everything already placed in the segment.
class ScatterFeature extends Feature {
  /// Which entity to place (must match a key in the biome's entity manifest).
  final String entityName;

  /// Noise frequency — smaller values produce broad, rolling hills of density;
  /// larger values create tight, patchy clusters.
  final double noiseScale;

  /// Noise must exceed this to allow spawning. 0.0 = always active, 0.9 = only
  /// at the tallest noise peaks. Controls overall rarity.
  final double threshold;

  /// Spacing range (in tiles) when the layer is active. Noise interpolates
  /// between these — high noise → minGap (dense), low noise → maxGap (sparse).
  final int minGapTiles;
  final int maxGapTiles;

  /// Offset added to the world seed so this scatter samples different noise
  /// than its siblings. Just needs to be unique — the actual value doesn't
  /// matter.
  final int noiseSeedOffset;

  const ScatterFeature({
    required this.entityName,
    this.noiseScale = 0.03,
    this.threshold = 0.3,
    this.minGapTiles = 10,
    this.maxGapTiles = 25,
    this.noiseSeedOffset = 0,
  }) : assert(minGapTiles < maxGapTiles),
       assert(threshold >= 0 && threshold < 1.0);
}

/// A contiguous span that is placed once, claims a footprint, and lays out
/// its own child entities internally. Flower meadows, palm groves, pier
/// zones, and future composite content all share this shape.
class RegionFeature extends Feature {
  /// Stable identifier used to tag resulting footprints. Terrain/renderer code
  /// filters on this (e.g. `kind == 'pier'` drives the pier tile sprite).
  final String kind;

  /// Poisson spacing between instances of this region, in tiles.
  final int minSpacingTiles;
  final int maxSpacingTiles;

  /// Each placed instance picks a random width in this range (tiles).
  final int minWidthTiles;
  final int maxWidthTiles;

  /// Offset added to the world seed so this region samples independently from
  /// other features.
  final int noiseSeedOffset;

  /// Children laid out inside a placed region footprint.
  final List<RegionChild> children;

  /// If true, scatter features skip this footprint entirely, AND (for
  /// kind == 'pier') the footprint is exported to `WorldSegment.pierZones`.
  /// If false, scatters may still place inside, subject to size-aware
  /// collision against the region's children.
  final bool exclusive;

  /// If true, children sit at adjacent tiles with no collision check between
  /// them (flower meadows — colors mingle, overlap allowed). If false,
  /// children respect size-aware collision against each other.
  final bool allowChildOverlap;

  const RegionFeature({
    required this.kind,
    required this.minSpacingTiles,
    required this.maxSpacingTiles,
    required this.minWidthTiles,
    required this.maxWidthTiles,
    this.noiseSeedOffset = 0,
    this.children = const [],
    this.exclusive = false,
    this.allowChildOverlap = false,
  }) : assert(minSpacingTiles <= maxSpacingTiles),
       assert(minWidthTiles <= maxWidthTiles),
       assert(minWidthTiles > 0);
}

/// A small themed cluster of distinct entities placed together at a single
/// anchor point — e.g. a rest area (vending machine + bench + trash bin) or
/// a campfire scene. Each anchor lays down one of every child, in a shuffled
/// order, with adjacent size-aware spacing. Aborts the whole group if any
/// child can't fit, so partial clusters never appear.
class GroupFeature extends Feature {
  /// Stable identifier (informational; useful for debugging/logging).
  final String kind;

  /// Entity names placed once each per group instance, in shuffled order.
  final List<String> children;

  /// Poisson spacing between group anchors, in tiles.
  final int minGapTiles;
  final int maxGapTiles;

  /// Seed offset so this feature samples independently from siblings.
  final int noiseSeedOffset;

  const GroupFeature({
    required this.kind,
    required this.children,
    required this.minGapTiles,
    required this.maxGapTiles,
    this.noiseSeedOffset = 0,
  }) : assert(minGapTiles <= maxGapTiles);
}

class RegionChild {
  final String entityName;

  /// Weight for the weighted pick when `allowChildOverlap` is true. Ignored
  /// otherwise (siblings are placed sequentially in list order).
  final double weight;

  /// Minimum gap between successive child emissions inside a region, in
  /// tiles. 1 = adjacent tiles. A small random jitter is added on top.
  final int minGapTiles;

  const RegionChild({
    required this.entityName,
    this.weight = 1.0,
    this.minGapTiles = 1,
  }) : assert(weight >= 0),
       assert(minGapTiles >= 1);
}

/// Per-creature animation config (row indices, frame counts, step times).
/// Lives on [CreatureSpriteDef] so biome registry entries can describe
/// creatures declaratively without a separate JSON manifest.
class CreatureAnimConfig {
  final int idleRow;
  final int idleFrames;
  final double idleStepTime;

  final int hopRow;
  final int hopFrames;
  final double hopStepTime;

  /// Row/frame counts for animations we load but don't trigger in the MVP.
  /// Keeping them on the config keeps the sheet slicing exercised so a future
  /// predator ticket doesn't discover broken row indexes.
  final int hitRow;
  final int hitFrames;
  final double hitStepTime;

  final int deathRow;
  final int deathFrames;
  final double deathStepTime;

  const CreatureAnimConfig({
    this.idleRow = 0,
    this.idleFrames = 4,
    this.idleStepTime = 0.18,
    this.hopRow = 1,
    this.hopFrames = 4,
    this.hopStepTime = 0.12,
    this.hitRow = 2,
    this.hitFrames = 2,
    this.hitStepTime = 0.14,
    this.deathRow = 3,
    this.deathFrames = 3,
    this.deathStepTime = 0.18,
  });
}

/// Describes a creature's sprite sheet layout and default behavior. Held in
/// [BiomeDefinition.creatureDefs] so a biome declares its entire creature
/// roster inline.
///
/// Frame size is stored as two `double`s rather than a `Vector2` so the
/// whole def (and the enclosing biome literal) stays `const`-constructible
/// — Flame's `Vector2` is a mutable class and can't appear in const context.
class CreatureSpriteDef {
  /// Path relative to the `images/` directory (Flame's images cache root).
  final String sheetPath;
  final double frameWidth;
  final double frameHeight;
  final double scale;
  final CreatureAnimConfig animConfig;
  final List<BehaviorConfig> behaviors;

  /// If non-empty, a color is picked from this list (seeded by the creature's
  /// item index) and applied as a `BlendMode.modulate` tint — perfect for
  /// recoloring greyscale/white art like the butterfly sheet.
  final List<Color> tintPalette;

  /// Nearest-neighbor decimation factor applied to the sheet at load time.
  /// A value of 2 means every 2×2 block of source pixels collapses to 1 —
  /// effectively halving the art's resolution so pixels read chunkier when
  /// paired with an integer render scale.
  final int sourceDownsample;

  const CreatureSpriteDef({
    required this.sheetPath,
    required this.frameWidth,
    required this.frameHeight,
    required this.scale,
    required this.animConfig,
    this.behaviors = const [],
    this.tintPalette = const [],
    this.sourceDownsample = 1,
  }) : assert(sourceDownsample >= 1);
}

class BiomeDefinition {
  final BiomeType type;
  final String terrainAsset;
  final String entitySheet;
  final String entityManifest;
  final List<String> parallaxLayers;
  final Terrain footstepTerrain;

  /// All placement features for this biome, scatters + regions mixed freely.
  /// Generation processes regions first (claim footprints), then scatters
  /// (fill the rest subject to size-aware collision).
  final List<Feature> features;

  final int minCoinGapTiles;
  final int maxCoinGapTiles;

  /// Independent probability that a coin slot becomes a diamond.
  final double diamondChance;

  /// Independent probability that a coin slot becomes a two-coin cluster.
  /// The remaining probability (`1 - diamondChance - clusterChance`) spawns
  /// a single coin.
  final double clusterChance;

  /// Creature roster for this biome. Empty list means no ambient creatures.
  final List<WeightedEntity> creatureWeights;
  final int minCreatureGapTiles;
  final int maxCreatureGapTiles;

  /// Sprite/behavior config for each creature name in [creatureWeights].
  final Map<String, CreatureSpriteDef> creatureDefs;

  /// Optional ambient sky particles (snow, sakura, fireflies, etc.).
  /// `null` means no overlay for this biome.
  final WeatherDef? weather;

  /// Source position of the surface tile in the terrain sheet.
  /// Stored as `[x, y]` rather than `Vector2` to keep `const`-constructible.
  final List<double> surfaceSrcPosition;

  /// Source position of the fill tile in the terrain sheet.
  final List<double> fillSrcPosition;

  const BiomeDefinition({
    required this.type,
    required this.terrainAsset,
    required this.entitySheet,
    required this.entityManifest,
    required this.parallaxLayers,
    required this.footstepTerrain,
    required this.features,
    required this.minCoinGapTiles,
    required this.maxCoinGapTiles,
    required this.diamondChance,
    required this.clusterChance,
    this.surfaceSrcPosition = const [64, 16],
    this.fillSrcPosition = const [64, 48],
    this.creatureWeights = const [],
    this.minCreatureGapTiles = 40,
    this.maxCreatureGapTiles = 80,
    this.creatureDefs = const {},
    this.weather,
  }) : assert(diamondChance >= 0 && clusterChance >= 0),
       assert(
         diamondChance + clusterChance <= 1.0,
         'diamondChance + clusterChance must not exceed 1.0',
       );

  int get totalCreatureWeight =>
      creatureWeights.fold(0, (sum, w) => sum + w.weight);
}
