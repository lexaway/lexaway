import 'dart:convert';

import 'package:flame/components.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../components/entity.dart';
import '../lexaway_game.dart';
import 'biome_registry.dart';
import 'scrolling_item_layer.dart';
import 'world_map.dart';

/// Materializes entities from the pre-generated [WorldMap] as the player
/// scrolls. Replaces the old random-spawning EntityManager.
class WorldRenderer extends ScrollingItemLayer<Entity> {
  /// Sprite definitions keyed by biome, then entity name.
  final Map<BiomeType, Map<String, _EntityDef>> _defs = {};

  WorldRenderer(WorldMap worldMap)
      : super(
          worldMap: worldMap,
          category: ItemCategory.entity,
          spawnMarginPx: 128,
          cullMarginPx: 128,
        );

  @override
  Future<void> onLoad() async {
    // Pre-load entity sprites for every biome present in the world.
    final biomes = worldMap.segments.map((s) => s.biome).toSet();
    for (final biome in biomes) {
      await _loadBiomeDefs(biome);
    }
  }

  Future<void> _loadBiomeDefs(BiomeType biome) async {
    final def = BiomeRegistry.get(biome);
    final jsonStr = await rootBundle.loadString(def.entityManifest);
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    final image = await game.images.load(def.entitySheet);
    final entities = json['entities'] as Map<String, dynamic>;

    final defs = <String, _EntityDef>{};
    for (final entry in entities.entries) {
      final e = entry.value as Map<String, dynamic>;
      final src = (e['src'] as List).cast<int>();
      final sz = (e['size'] as List).cast<int>();

      defs[entry.key] = _EntityDef(
        sprite: Sprite(
          image,
          srcPosition: Vector2(src[0].toDouble(), src[1].toDouble()),
          srcSize: Vector2(sz[0].toDouble(), sz[1].toDouble()),
        ),
        widthTiles: e['widthTiles'] as int,
        heightTiles: e['heightTiles'] as int,
      );
    }
    _defs[biome] = defs;
  }

  /// Load defs for a biome that wasn't present at startup (lazy extensions).
  Future<void> ensureBiomeLoaded(BiomeType biome) async {
    if (_defs.containsKey(biome)) return;
    await _loadBiomeDefs(biome);
  }

  @override
  Entity? createItem(PlacedItem item) {
    final biome = worldMap.biomeAt(item.worldX);
    final def = _defs[biome]?[item.name];
    if (def == null) return null;

    final scale = LexawayGame.pixelScale;
    final spriteSize = Vector2(
      def.widthTiles * 16.0 * scale,
      def.heightTiles * 16.0 * scale,
    );
    final groundTop = game.size.y * LexawayGame.groundLevel;

    return Entity(
      sprite: def.sprite,
      spriteSize: spriteSize,
      worldX: item.worldX,
      itemIndex: item.index,
    )..position.y = groundTop - spriteSize.y;
  }
}

class _EntityDef {
  final Sprite sprite;
  final int widthTiles;
  final int heightTiles;

  _EntityDef({
    required this.sprite,
    required this.widthTiles,
    required this.heightTiles,
  });
}
