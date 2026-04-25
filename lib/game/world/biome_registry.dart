import 'dart:ui';

import '../audio_manager.dart';
import '../components/behaviors/behavior_config.dart';
import '../lexaway_game.dart';
import 'biome_definition.dart';
import 'world_map.dart';

class BiomeRegistry {
  static const _grassland = BiomeDefinition(
    type: BiomeType.grassland,
    terrainAsset: 'terrain/grassland.png',
    entitySheet: 'entities/grassland.png',
    entityManifest: 'assets/images/entities/grassland.json',
    parallaxLayers: [
      'parallax/sky.png',
      'parallax/clouds_far.png',
      'parallax/clouds_near.png',
      'parallax/hills.png',
      'parallax/foreground.png',
    ],
    footstepTerrain: Terrain.grass,
    features: [
      // Bushes — everywhere, the bread and butter of grassland foliage.
      ScatterFeature(
        entityName: 'bush',
        noiseScale: 0.04,
        threshold: 0.2,
        minGapTiles: 5,
        maxGapTiles: 14,
        noiseSeedOffset: 0,
      ),
      // Signposts — sparse little wooden noticeboards along the path.
      ScatterFeature(
        entityName: 'sign',
        noiseScale: 0.06,
        threshold: 0.25,
        minGapTiles: 6,
        maxGapTiles: 16,
        noiseSeedOffset: 50,
      ),
      // Round trees — clumpy groves with broad noise.
      ScatterFeature(
        entityName: 'round_tree',
        noiseScale: 0.02,
        threshold: 0.25,
        minGapTiles: 7,
        maxGapTiles: 20,
        noiseSeedOffset: 100,
      ),
      // Pine trees — similar to round trees but offset noise = different groves.
      ScatterFeature(
        entityName: 'pine_tree',
        noiseScale: 0.02,
        threshold: 0.25,
        minGapTiles: 7,
        maxGapTiles: 20,
        noiseSeedOffset: 150,
      ),
      // Flower trees — less rare now, nice scattered blooms.
      ScatterFeature(
        entityName: 'flower_tree',
        noiseScale: 0.03,
        threshold: 0.35,
        minGapTiles: 8,
        maxGapTiles: 24,
        noiseSeedOffset: 200,
      ),
      // Fences — sparse, isolated stretches.
      ScatterFeature(
        entityName: 'fence',
        noiseScale: 0.015,
        threshold: 0.55,
        minGapTiles: 18,
        maxGapTiles: 40,
        noiseSeedOffset: 250,
      ),
      // Open-ended fences — bracketed segments, rare standalone runs.
      ScatterFeature(
        entityName: 'open_fence',
        noiseScale: 0.02,
        threshold: 0.6,
        minGapTiles: 20,
        maxGapTiles: 45,
        noiseSeedOffset: 300,
      ),
      // Flower meadow — a dense patch of mingling wildflowers, all four colors
      // sharing the same region so they interleave naturally instead of
      // forming mono-color blobs. `allowChildOverlap` lets colors sit on
      // adjacent tiles; scatters may still place inside (non-exclusive).
      RegionFeature(
        kind: 'flower_meadow',
        minSpacingTiles: 40,
        maxSpacingTiles: 120,
        minWidthTiles: 8,
        maxWidthTiles: 20,
        noiseSeedOffset: 1000,
        exclusive: false,
        allowChildOverlap: true,
        children: [
          RegionChild(entityName: 'flower_red', weight: 0.30, minGapTiles: 1),
          RegionChild(entityName: 'flower_orange', weight: 0.25, minGapTiles: 1),
          RegionChild(entityName: 'flower_yellow', weight: 0.25, minGapTiles: 1),
          RegionChild(entityName: 'flower_blue', weight: 0.20, minGapTiles: 1),
        ],
      ),
    ],
    minCoinGapTiles: 5,
    maxCoinGapTiles: 10,
    diamondChance: 0.15, // 15% diamond, 25% cluster, 60% single coin
    clusterChance: 0.25,
    creatureWeights: [
      WeightedEntity('minibunny', 2),
      WeightedEntity('butterfly', 3),
    ],
    minCreatureGapTiles: 40,
    maxCreatureGapTiles: 80,
    creatureDefs: {
      'minibunny': CreatureSpriteDef(
        sheetPath: 'creatures/minibunny.png',
        frameWidth: 32,
        frameHeight: 32,
        scale: LexawayGame.pixelScale,
        animConfig: CreatureAnimConfig(),
        behaviors: [
          GroundAnchorConfig(),
          FleeConfig(),
          IdleHopConfig(),
        ],
      ),
      'butterfly': CreatureSpriteDef(
        sheetPath: 'creatures/butterfly.png',
        frameWidth: 52,
        frameHeight: 52,
        scale: LexawayGame.pixelScale * 0.20,
        sourceDownsample: 4,
        animConfig: CreatureAnimConfig(
          idleFrames: 8,
          idleStepTime: 0.07,
          hopRow: 0,
          hopFrames: 1,
          hitRow: 0,
          hitFrames: 1,
          deathRow: 0,
          deathFrames: 1,
        ),
        behaviors: [
          FlightConfig(
            minAltitude: 40,
            maxAltitude: 240,
            bobAmplitude: 10,
            bobFrequency: 1.4,
            driftSpeed: -25,
            swayAmplitude: 14,
            swayFrequency: 2.2,
          ),
        ],
        tintPalette: [
          Color(0xFFFF7A3D), // monarch orange
          Color(0xFF5DA9FF), // morpho blue
          Color(0xFFFF8FD1), // pink
          Color(0xFFBDF26B), // lime
          Color(0xFFC79BFF), // lavender
          Color(0xFFFFE45E), // sulphur yellow
        ],
      ),
    },
  );

  static const _tropics = BiomeDefinition(
    type: BiomeType.tropics,
    terrainAsset: 'terrain/tropics.png',
    entitySheet: 'entities/tropics.png',
    entityManifest: 'assets/images/entities/tropics.json',
    parallaxLayers: [
      'parallax/sky.png',
      'parallax/tropics_clouds_far.png',
      'parallax/tropics_clouds_near.png',
      'parallax/tropics_water.png',
    ],
    footstepTerrain: Terrain.dirt,
    features: [
      // Piers — exclusive coastal platforms; their footprints are exported to
      // `WorldSegment.pierZones` so the terrain renderer can swap tiles.
      // No entity children for now; the pier is purely a terrain feature.
      RegionFeature(
        kind: 'pier',
        minSpacingTiles: 15,
        maxSpacingTiles: 60,
        minWidthTiles: 5,
        maxWidthTiles: 12,
        noiseSeedOffset: 2000,
        exclusive: true,
        allowChildOverlap: false,
        children: [],
      ),
      // Palm trees — dominant, dense groves rolling across the coast.
      ScatterFeature(
        entityName: 'palm_tree',
        noiseScale: 0.025,
        threshold: 0.2,
        minGapTiles: 5,
        maxGapTiles: 16,
        noiseSeedOffset: 0,
      ),
      // Wooden fences — medium frequency, independent rhythm.
      ScatterFeature(
        entityName: 'wooden_fence',
        noiseScale: 0.04,
        threshold: 0.35,
        minGapTiles: 12,
        maxGapTiles: 28,
        noiseSeedOffset: 100,
      ),
      // Rocks — scattered boulders, fairly sparse.
      ScatterFeature(
        entityName: 'rock',
        noiseScale: 0.05,
        threshold: 0.35,
        minGapTiles: 12,
        maxGapTiles: 28,
        noiseSeedOffset: 200,
      ),
      // Flower meadow — hibiscus-ish pops clustered between the palms.
      RegionFeature(
        kind: 'flower_meadow',
        minSpacingTiles: 40,
        maxSpacingTiles: 120,
        minWidthTiles: 8,
        maxWidthTiles: 20,
        noiseSeedOffset: 1000,
        exclusive: false,
        allowChildOverlap: true,
        children: [
          RegionChild(entityName: 'flower_red', weight: 0.30, minGapTiles: 1),
          RegionChild(entityName: 'flower_orange', weight: 0.25, minGapTiles: 1),
          RegionChild(entityName: 'flower_yellow', weight: 0.25, minGapTiles: 1),
          RegionChild(entityName: 'flower_blue', weight: 0.20, minGapTiles: 1),
        ],
      ),
    ],
    minCoinGapTiles: 5,
    maxCoinGapTiles: 10,
    diamondChance: 0.15,
    clusterChance: 0.25,
  );

  static const _winter = BiomeDefinition(
    type: BiomeType.winter,
    terrainAsset: 'terrain/winter.png',
    entitySheet: 'entities/winter.png',
    entityManifest: 'assets/images/entities/winter.json',
    parallaxLayers: [
      'parallax/sky.png',
      'parallax/winter_mountains_far.png',
      'parallax/winter_mountains_near.png',
      'parallax/winter_foreground.png',
    ],
    footstepTerrain: Terrain.snow,
    features: [
      // Snowy pines — light blue conifers, the iconic winter silhouette.
      ScatterFeature(
        entityName: 'snow_pine',
        noiseScale: 0.02,
        threshold: 0.25,
        minGapTiles: 7,
        maxGapTiles: 20,
        noiseSeedOffset: 0,
      ),
      // Evergreens — dark green firs, offset noise = different groves.
      ScatterFeature(
        entityName: 'evergreen',
        noiseScale: 0.02,
        threshold: 0.30,
        minGapTiles: 8,
        maxGapTiles: 22,
        noiseSeedOffset: 100,
      ),
      // Snow bushes — frequent little tufts.
      ScatterFeature(
        entityName: 'snow_bush',
        noiseScale: 0.04,
        threshold: 0.20,
        minGapTiles: 5,
        maxGapTiles: 14,
        noiseSeedOffset: 200,
      ),
      // Snow mounds — slightly rarer drifts.
      ScatterFeature(
        entityName: 'snow_mound',
        noiseScale: 0.06,
        threshold: 0.30,
        minGapTiles: 6,
        maxGapTiles: 16,
        noiseSeedOffset: 300,
      ),
      // Winter fences — sparse stretches of icy wooden posts.
      ScatterFeature(
        entityName: 'winter_fence',
        noiseScale: 0.015,
        threshold: 0.55,
        minGapTiles: 18,
        maxGapTiles: 40,
        noiseSeedOffset: 400,
      ),
      // Open-ended winter fences — bracketed standalone runs, rarer.
      ScatterFeature(
        entityName: 'winter_open_fence',
        noiseScale: 0.02,
        threshold: 0.6,
        minGapTiles: 20,
        maxGapTiles: 45,
        noiseSeedOffset: 500,
      ),
    ],
    minCoinGapTiles: 5,
    maxCoinGapTiles: 10,
    diamondChance: 0.15,
    clusterChance: 0.25,
  );

  static BiomeDefinition get(BiomeType type) {
    switch (type) {
      case BiomeType.grassland:
        return _grassland;
      case BiomeType.tropics:
        return _tropics;
      case BiomeType.winter:
        return _winter;
    }
  }
}
