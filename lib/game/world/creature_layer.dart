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

  CreatureLayer({required super.worldMap, required super.camera})
      : super(
          category: ItemCategory.creature,
          spawnMarginPx: 640,
          cullMarginPx: 128,
          // Creatures mutate their worldX at runtime (flee, drift, etc.)
          // so once one leaves the viewport, spawning a fresh copy at the
          // PlacedItem's static coordinate would pop in wherever that
          // coordinate now happens to be on-screen.
          cullPermanent: true,
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
  void update(double dt) {
    // Fleeing creatures can sprint off-screen faster than the cull margin
    // catches up — mark them eagerly so they can't re-spawn during the
    // in-flight frames. Idempotent; normal cull also marks them.
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
