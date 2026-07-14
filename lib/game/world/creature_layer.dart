import '../components/creature.dart';
import 'biome_registry.dart';
import 'scrolling_item_layer.dart';
import 'world_map.dart';

/// Streams ambient creatures from the [WorldMap] as the player scrolls.
/// Parallel to [WorldRenderer] but for animated critters, not static
/// scenery.
class CreatureLayer extends ScrollingItemLayer<Creature> {
  /// Biomes whose creature sheets are pre-warmed into the image cache. A
  /// set, not a def map — defs live on [BiomeRegistry] and are cheap to
  /// read; [_ensureBiome]'s real work is the PNG load.
  final Set<BiomeType> _loadedBiomes = {};

  CreatureLayer({required super.worldMap, required super.camera})
      : super(
          category: ItemCategory.creature,
          spawnMarginPx: 640,
          cullMarginPx: 128,
          // Creatures mutate worldX at runtime (flee, drift), so re-spawning
          // from the static PlacedItem coordinate would pop them in mid-view.
          cullPermanent: true,
        );

  @override
  Future<void> onLoad() async {
    final biomes = worldMap.segments.map((s) => s.biome).toSet();
    for (final biome in biomes) {
      await _ensureBiome(biome);
    }
  }

  /// Pre-warm every creature sheet for [biome] so the first one into view
  /// doesn't stall on a sync PNG decode.
  Future<void> _ensureBiome(BiomeType biome) async {
    if (_loadedBiomes.contains(biome)) return;
    final def = BiomeRegistry.get(biome);
    for (final entry in def.creatureDefs.values) {
      await game.images.load(entry.sheetPath);
    }
    _loadedBiomes.add(biome);
  }

  /// Call when [WorldStreamer] extends the map into a biome absent at
  /// startup.
  Future<void> ensureBiomeLoaded(BiomeType biome) => _ensureBiome(biome);

  @override
  void update(double dt) {
    // Fleeing creatures can outrun the cull margin — mark eagerly so they
    // can't re-spawn in the in-flight frames. Idempotent.
    for (final entry in activeItems.entries) {
      if (entry.value.isExcited) markCulled(entry.key);
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
      animConfig: def.animConfig,
      behaviorConfigs: def.behaviors,
      worldX: item.worldX,
      itemIndex: item.index,
      tintPalette: def.tintPalette,
      sourceDownsample: def.sourceDownsample,
    );
  }
}
