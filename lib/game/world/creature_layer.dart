import '../components/creature.dart';
import 'biome_registry.dart';
import 'scrolling_item_layer.dart';
import 'world_map.dart';

/// Streams ambient creatures from the pre-generated [WorldMap] as the player
/// scrolls. Parallel to [WorldRenderer] but for animated critters rather
/// than static scenery.
class CreatureLayer extends ScrollingItemLayer<Creature> {
  /// Biomes whose creature sprite sheets have been pre-warmed into the
  /// image cache. Tracked as a set (rather than a def map) because the
  /// actual defs live on [BiomeRegistry] and are cheap to read on demand
  /// — the only real work [_ensureBiome] does is the PNG load.
  final Set<BiomeType> _loadedBiomes = {};

  /// Indices of creatures that have already fled off-screen. Prevents
  /// respawning at their original world position.
  final Set<int> _fledIndices = {};

  CreatureLayer(WorldMap worldMap)
      : super(
          worldMap: worldMap,
          category: ItemCategory.creature,
          spawnMarginPx: 640,
          cullMarginPx: 128,
        );

  @override
  Future<void> onLoad() async {
    final biomes = worldMap.segments.map((s) => s.biome).toSet();
    for (final biome in biomes) {
      await _ensureBiome(biome);
    }
  }

  /// Pre-warm every creature sheet for [biome] into Flame's image cache so
  /// the first bunny into view doesn't stall on a sync PNG decode.
  Future<void> _ensureBiome(BiomeType biome) async {
    if (_loadedBiomes.contains(biome)) return;
    final def = BiomeRegistry.get(biome);
    for (final entry in def.creatureDefs.values) {
      await game.images.load(entry.sheetPath);
    }
    _loadedBiomes.add(biome);
  }

  /// Call when [WorldStreamer] extends the map into a biome that wasn't
  /// present at startup. No-op in Phase 1 (grassland-only) but kept so the
  /// wiring exists when Phase 2 adds new biomes.
  Future<void> ensureBiomeLoaded(BiomeType biome) => _ensureBiome(biome);

  @override
  bool shouldSkip(int index) => _fledIndices.contains(index);

  @override
  void update(double dt) {
    // Tag fleeing creatures before the base class culls them.
    for (final entry in activeItems.entries) {
      if (entry.value.fleeing) _fledIndices.add(entry.key);
    }
    super.update(dt);
  }

  @override
  Creature? createItem(PlacedItem item) {
    final biome = worldMap.biomeAt(item.worldX);
    final def = BiomeRegistry.get(biome).creatureDefs[item.name];
    if (def == null) return null;

    return Creature(
      sheetPath: def.sheetPath,
      frameWidth: def.frameWidth,
      frameHeight: def.frameHeight,
      spriteScale: def.scale,
      behavior: def.behavior,
      worldX: item.worldX,
      itemIndex: item.index,
    );
  }
}
