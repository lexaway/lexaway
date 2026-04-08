import '../audio_manager.dart';
import 'world_map.dart';

class WeightedEntity {
  final String name;
  final int weight;

  const WeightedEntity(this.name, this.weight);
}

class BiomeDefinition {
  final BiomeType type;
  final String terrainAsset;
  final String entitySheet;
  final String entityManifest;
  final List<String> parallaxLayers;
  final Terrain footstepTerrain;

  final List<WeightedEntity> entityWeights;
  final int minEntityGapTiles;
  final int maxEntityGapTiles;

  final int minCoinGapTiles;
  final int maxCoinGapTiles;
  final double diamondChance;
  final double clusterChance;

  const BiomeDefinition({
    required this.type,
    required this.terrainAsset,
    required this.entitySheet,
    required this.entityManifest,
    required this.parallaxLayers,
    required this.footstepTerrain,
    required this.entityWeights,
    required this.minEntityGapTiles,
    required this.maxEntityGapTiles,
    required this.minCoinGapTiles,
    required this.maxCoinGapTiles,
    required this.diamondChance,
    required this.clusterChance,
  });

  int get totalEntityWeight =>
      entityWeights.fold(0, (sum, w) => sum + w.weight);
}
