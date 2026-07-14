import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'biome_registry.dart';
import 'world_map.dart';

/// Entity widthTiles per biome, parsed from each biome's entity manifest.
/// Drives collision-aware placement so a 3-tile palm clears a pier zone by
/// its full width, not just its center.
typedef EntityFootprints = Map<BiomeType, Map<String, int>>;

/// Parses every biome's entity manifest into widthTiles keyed by biome and
/// entity name. Call once at boot before world generation.
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
