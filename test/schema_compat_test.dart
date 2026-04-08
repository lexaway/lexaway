import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexaway/data/pack_manager.dart';
import 'package:lexaway/game/world/world_generator.dart';
import 'package:lexaway/game/world/world_map.dart';
import 'package:lexaway/main.dart' show hiveSchemaVersion;

/// Fixture-based tests that verify current code can still read persisted data
/// from every shipped schema version. If a code change breaks deserialization,
/// these tests fail — forcing a migration before merge.
///
/// To add a new schema version:
///   1. Copy the latest fixture → hive_vN.json
///   2. Adjust values to match the new shape
///   3. Bump the version constants
///   4. Add migration logic so older fixtures still pass
void main() {
  late Map<String, dynamic> fixture;

  setUp(() {
    final file = File('test/fixtures/hive_v1.json');
    fixture = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  });

  group('Hive box v1 compatibility', () {
    test('fixture version matches current hiveSchemaVersion', () {
      expect(fixture['hive_schema_version'], equals(hiveSchemaVersion));
    });

    test('settings keys deserialize the way providers cast them', () {
      // Providers cast with (box.get(key) as num).toDouble() or as bool/String.
      // Exercise those exact casts here.
      expect((fixture['vol_master'] as num).toDouble(), isA<double>());
      expect((fixture['vol_sfx'] as num).toDouble(), isA<double>());
      expect((fixture['vol_tts'] as num).toDouble(), isA<double>());
      expect(fixture['haptics'] as bool, isA<bool>());
      expect(fixture['gender'] as String, isA<String>());
      expect(fixture['ui_locale'] as String, isA<String>());
    });

    test('progress counters survive the HiveIntNotifier cast', () {
      // HiveIntNotifier does: box.get(key, defaultValue: 0) as int
      expect(fixture['streak'] as int, isA<int>());
      expect(fixture['best_streak'] as int, isA<int>());
      expect(fixture['coins'] as int, isA<int>());
      expect(fixture['steps'] as int, isA<int>());
    });

    test('pack metadata matches PackManager expectations', () {
      final packs = fixture['packs'] as Map<String, dynamic>;
      for (final entry in packs.entries) {
        // Keys are now composite packIds like "eng-fra"
        expect(entry.key, contains('-'));
        final pack = Map<String, dynamic>.from(entry.value as Map);
        expect(pack['schema_version'] as int, isA<int>());
        expect(pack['built_at'] as String, isA<String>());
        expect(pack['size_bytes'] as int, isA<int>());
      }
    });

    test('manifest_cache deserializes through Manifest.fromJson', () {
      final raw = fixture['manifest_cache'] as String;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final manifest = Manifest.fromJson(json);
      expect(manifest.schemaVersion, equals(1));
      expect(manifest.packs, isNotEmpty);
      expect(manifest.packs.first.lang, equals('fra'));
      expect(manifest.packs.first.fromLang, equals('eng'));
    });

    test('tts model metadata matches TtsManager expectations', () {
      final models = fixture['tts_models'] as Map<String, dynamic>;
      for (final entry in models.values) {
        final model = Map<String, dynamic>.from(entry as Map);
        expect(model['archive_name'] as String, isA<String>());
        expect(model['downloaded_at'] as String, isA<String>());
      }
    });
  });

  group('World state', () {
    test('world state fixture has expected keys', () {
      final world = Map<String, dynamic>.from(fixture['world'] as Map);
      expect(world['seed'], isA<int>());
      expect((world['scroll_offset'] as num).toDouble(), isA<double>());
      expect(world['collected_coins'], isA<List>());
      expect(world['extensions'], isA<int>());
    });

    test('world regenerates deterministically from seed', () {
      final world = Map<String, dynamic>.from(fixture['world'] as Map);
      final seed = world['seed'] as int;
      final map1 = WorldGenerator().generate(seed);
      final map2 = WorldGenerator().generate(seed);

      expect(map1.segments.length, equals(map2.segments.length));
      for (var i = 0; i < map1.segments.length; i++) {
        expect(map1.segments[i].startTile, equals(map2.segments[i].startTile));
        expect(map1.segments[i].endTile, equals(map2.segments[i].endTile));
        expect(map1.segments[i].items.length,
            equals(map2.segments[i].items.length));
        for (var j = 0; j < map1.segments[i].items.length; j++) {
          expect(map1.segments[i].items[j].worldX,
              equals(map2.segments[i].items[j].worldX));
          expect(map1.segments[i].items[j].name,
              equals(map2.segments[i].items[j].name));
        }
      }
    });

    test('collected_coins indices are respected', () {
      final world = Map<String, dynamic>.from(fixture['world'] as Map);
      final collected = (world['collected_coins'] as List).cast<int>().toSet();
      final seed = world['seed'] as int;
      final map = WorldGenerator().generate(seed);

      final allCoinIndices = map.segments
          .expand((s) => s.items)
          .where((item) => item.category == ItemCategory.coin)
          .map((item) => item.index)
          .toSet();

      // All collected indices should be valid coin indices in the world.
      for (final idx in collected) {
        expect(allCoinIndices, contains(idx));
      }
    });
  });
}
