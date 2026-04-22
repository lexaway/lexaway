import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'biome_registry.dart';
import 'world_map.dart';

/// Entity widthTiles per biome, parsed from each biome's entity manifest.
/// The [WorldGenerator] uses this for collision-aware placement — e.g. so a
/// 3-tile-wide palm tree knows to stay clear of a pier zone, not just its
/// center point.
typedef EntityFootprints = Map<BiomeType, Map<String, int>>;

/// Parses every biome's entity manifest and returns the widthTiles of each
/// entity, keyed by biome and entity name. Call once at boot before kicking
/// off world generation.
Future<EntityFootprints> loadEntityFootprints() async {
  final result = <BiomeType, Map<String, int>>{};
  for (final biome in BiomeType.values) {
    final def = BiomeRegistry.get(biome);
    final jsonStr = await rootBundle.loadString(def.entityManifest);
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    final entities = json['entities'] as Map<String, dynamic>;
    result[biome] = {
      for (final entry in entities.entries)
        entry.key: (entry.value as Map<String, dynamic>)['widthTiles'] as int,
    };
  }
  return result;
}
