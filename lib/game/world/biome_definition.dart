import '../audio_manager.dart';
import 'world_map.dart';

class WeightedEntity {
  final String name;
  final int weight;

  const WeightedEntity(this.name, this.weight);
}

/// One noise-driven placement layer for a single entity type.
///
/// Each layer runs its own independent Poisson disk pass, with density
/// modulated by 1D value noise. Stack layers like Minecraft stacks Perlin
/// octaves — each one controls a single entity type's distribution.
class SpawnLayer {
  /// Which entity to place (must match a key in the biome's entity manifest).
  final String entityName;

  /// Noise frequency — smaller values produce broad, rolling hills of density;
  /// larger values create tight, patchy clusters.
  final double noiseScale;

  /// Noise must exceed this to allow any spawning. 0.0 = always active,
  /// 0.9 = only at the tallest noise peaks. Controls overall rarity.
  final double threshold;

  /// Spacing range (in tiles) when the layer is active. Noise interpolates
  /// between these — high noise → minGap (dense), low noise → maxGap (sparse).
  final int minGapTiles;
  final int maxGapTiles;

  /// Offset added to the world seed so this layer samples different noise than
  /// its siblings. Just needs to be unique per layer — the actual value doesn't
  /// matter.
  final int noiseSeedOffset;

  const SpawnLayer({
    required this.entityName,
    this.noiseScale = 0.03,
    this.threshold = 0.3,
    this.minGapTiles = 10,
    this.maxGapTiles = 25,
    this.noiseSeedOffset = 0,
  }) : assert(minGapTiles < maxGapTiles),
       assert(threshold >= 0 && threshold < 1.0);
}

/// Per-creature animation + behavior config. Lives on [CreatureSpriteDef]
/// so biome registry entries can describe creatures declaratively without a
/// separate JSON manifest (we only have one creature today).
class CreatureBehavior {
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

  /// Seconds between hops (inclusive lower bound, exclusive upper).
  final double minHopIntervalSec;
  final double maxHopIntervalSec;

  const CreatureBehavior({
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
    this.minHopIntervalSec = 4.0,
    this.maxHopIntervalSec = 9.0,
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
  final CreatureBehavior behavior;

  const CreatureSpriteDef({
    required this.sheetPath,
    required this.frameWidth,
    required this.frameHeight,
    required this.scale,
    required this.behavior,
  });
}

class BiomeDefinition {
  final BiomeType type;
  final String terrainAsset;
  final String entitySheet;
  final String entityManifest;
  final List<String> parallaxLayers;
  final Terrain footstepTerrain;

  /// Independent spawn layers — one per entity type (or group). Each layer
  /// runs its own noise-modulated Poisson disk pass. The generator merges
  /// results and resolves collisions afterward.
  final List<SpawnLayer> entityLayers;

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
    required this.entityLayers,
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
  }) : assert(diamondChance >= 0 && clusterChance >= 0),
       assert(
         diamondChance + clusterChance <= 1.0,
         'diamondChance + clusterChance must not exceed 1.0',
       );

  int get totalCreatureWeight =>
      creatureWeights.fold(0, (sum, w) => sum + w.weight);
}
