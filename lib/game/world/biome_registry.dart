import '../audio_manager.dart';
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
    entityWeights: [
      WeightedEntity('bush', 25),
      WeightedEntity('mushroom', 20),
      WeightedEntity('round_tree', 15),
      WeightedEntity('pine_tree', 15),
      WeightedEntity('flower_tree', 10),
      WeightedEntity('fence', 10),
      WeightedEntity('flower_fence', 5),
    ],
    minEntityGapTiles: 8,
    maxEntityGapTiles: 20,
    minCoinGapTiles: 5,
    maxCoinGapTiles: 10,
    diamondChance: 0.15, // 15% diamond, 25% cluster, 60% single coin
    clusterChance: 0.25,
    creatureWeights: [WeightedEntity('minibunny', 1)],
    minCreatureGapTiles: 40,
    maxCreatureGapTiles: 80,
    creatureDefs: {
      'minibunny': CreatureSpriteDef(
        sheetPath: 'creatures/minibunny.png',
        frameWidth: 32,
        frameHeight: 32,
        scale: LexawayGame.pixelScale,
        behavior: CreatureBehavior(),
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
    entityWeights: [
      WeightedEntity('palm_tree', 30),
      WeightedEntity('wooden_fence', 25),
      WeightedEntity('rock', 25),
    ],
    minEntityGapTiles: 8,
    maxEntityGapTiles: 20,
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
    }
  }
}
