import 'package:flutter_test/flutter_test.dart';
import 'package:lexaway/game/world/world_generator.dart';
import 'package:lexaway/game/world/world_map.dart';

/// FNV-1a over the dump string — stable across VMs, unlike String.hashCode.
String _fnv1a(String s) {
  var hash = 0xcbf29ce484222325;
  for (final unit in s.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  return hash.toRadixString(16);
}

String _dump(WorldMap map) {
  final b = StringBuffer('seed=${map.seed} next=${map.nextItemIndex};');
  for (final seg in map.segments) {
    b.write('${seg.biome.name}:${seg.startTile}-${seg.endTile}');
    for (final z in seg.pierZones) {
      b.write('|pier:${z.startTile}-${z.endTile}');
    }
    for (final item in seg.items) {
      b.write(
        '|${item.index}:${item.name}:${item.category.name}'
        ':${item.worldX.toStringAsFixed(3)}',
      );
    }
    b.write(';');
  }
  return b.toString();
}

void main() {
  group('WorldGenerator', () {
    test('same seed generates the same world', () {
      final a = WorldGenerator().generate(1234, totalTiles: 1500);
      final b = WorldGenerator().generate(1234, totalTiles: 1500);
      expect(_dump(a), _dump(b));
    });

    test('extension continues item indices from startIndex', () {
      final base = WorldGenerator().generate(42, totalTiles: 600);
      final ext = WorldGenerator().generate(
        42,
        totalTiles: 600,
        startTile: base.segments.last.endTile,
        startIndex: base.nextItemIndex,
      );
      expect(ext.segments.first.startTile, base.segments.last.endTile);
      final extIndices = [
        for (final seg in ext.segments)
          for (final item in seg.items) item.index,
      ];
      expect(extIndices, isNotEmpty);
      expect(
        extIndices.reduce((a, b) => a < b ? a : b),
        base.nextItemIndex,
        reason: 'extension indices must not collide with the base world',
      );
    });

    // Golden fingerprints. Seeded generation is persisted world state — if
    // one of these moves, existing players' worlds reshuffle under their
    // feet. Only update deliberately. Last regenerated when the autumn biome
    // joined the _pickBiome distribution (accepted reshuffle, same call as
    // the winter biome's introduction).
    test('seeded layout is stable across refactors', () {
      const golden = {
        1: '275f3950dfd9ebbe',
        1234: '1128616e68a91f30',
        987654321: '-4473b712fcef133d',
      };
      for (final entry in golden.entries) {
        final map = WorldGenerator().generate(entry.key, totalTiles: 1500);
        expect(_fnv1a(_dump(map)), entry.value, reason: 'seed ${entry.key}');
      }
    });
  });
}
