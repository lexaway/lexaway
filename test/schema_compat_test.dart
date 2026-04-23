import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:lexaway/data/hive_keys.dart';
import 'package:lexaway/data/pack_manager.dart';
import 'package:lexaway/data/tts_manager.dart' show ttsModelRegistry;
import 'package:lexaway/game/world/world_generator.dart';
import 'package:lexaway/game/world/world_map.dart';
import 'package:lexaway/main.dart' show hiveSchemaVersion, migrateHive;

/// Fixture-based tests that verify current code can still read persisted data
/// from every shipped schema version. If a code change breaks deserialization,
/// these tests fail — forcing a migration before merge.
///
/// Structure:
///   - Each shipped schema version has a `hive_vN.json` fixture captured at
///     release time and never mutated afterwards.
///   - Per-version groups deserialize the fixture through the same casts the
///     app code uses, proving wire compatibility.
///   - `migrateHive` is exercised end-to-end from v1 → current via a real
///     in-memory Hive box.
///
/// To add a new schema version:
///   1. Copy the previous fixture → `hive_vN.json` and adjust to the new shape
///   2. Bump `hiveSchemaVersion` in main.dart and add a case in `migrateHive`
///   3. Add a new group below targeting the new fixture
///   4. Extend the migration test so v1 → current still lands correctly
Map<String, dynamic> _loadFixture(String name) {
  final file = File('test/fixtures/$name');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  group('Hive box v1 compatibility (legacy snapshot)', () {
    late Map<String, dynamic> fixture;
    setUp(() => fixture = _loadFixture('hive_v1.json'));

    test('settings keys deserialize the way providers cast them', () {
      expect((fixture['vol_master'] as num).toDouble(), isA<double>());
      expect((fixture['vol_sfx'] as num).toDouble(), isA<double>());
      expect((fixture['vol_tts'] as num).toDouble(), isA<double>());
      expect(fixture['haptics'] as bool, isA<bool>());
      expect(fixture['gender'] as String, isA<String>());
      expect(fixture['ui_locale'] as String, isA<String>());
    });

    test('legacy progress counters (pre-v2 shape)', () {
      expect(fixture['streak'] as int, isA<int>());
      expect(fixture['best_streak'] as int, isA<int>());
      expect(fixture['coins'] as int, isA<int>());
      expect(fixture['steps'] as int, isA<int>());
    });

    test('manifest_cache still deserializes through Manifest.fromJson', () {
      final raw = fixture['manifest_cache'] as String;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final manifest = Manifest.fromJson(json);
      expect(manifest.schemaVersion, equals(1));
      expect(manifest.packs, isNotEmpty);
    });
  });

  group('Hive box v2 compatibility (current)', () {
    late Map<String, dynamic> fixture;
    setUp(() => fixture = _loadFixture('hive_v2.json'));

    test('fixture version matches current hiveSchemaVersion', () {
      expect(fixture['hive_schema_version'], equals(hiveSchemaVersion));
    });

    test('settings keys deserialize the way providers cast them', () {
      expect((fixture['vol_master'] as num).toDouble(), isA<double>());
      expect((fixture['vol_sfx'] as num).toDouble(), isA<double>());
      expect((fixture['vol_tts'] as num).toDouble(), isA<double>());
      expect(fixture['haptics'] as bool, isA<bool>());
      expect(fixture['gender'] as String, isA<String>());
      expect(fixture['ui_locale'] as String, isA<String>());
    });

    test('progress counters survive the HiveIntNotifier cast', () {
      expect(fixture['streak'] as int, isA<int>());
      expect(fixture['best_streak'] as int, isA<int>());
      expect(fixture['coins'] as int, isA<int>());
    });

    test('daily step counters match StepsNotifier expectations', () {
      expect(fixture['steps_lifetime'] as int, isA<int>());
      expect(fixture['steps_today'] as int, isA<int>());
      expect(fixture['steps_day_key'] as String, isA<String>());
    });

    test('daily goal + reminder prefs deserialize', () {
      expect(fixture['daily_goal'] as int, isA<int>());
      expect(fixture['reminder_enabled'] as bool, isA<bool>());
      expect(fixture['reminder_time'] as String, isA<String>());
    });

    test('pack metadata matches PackManager expectations', () {
      final packs = fixture['packs'] as Map<String, dynamic>;
      for (final entry in packs.entries) {
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
      final allArchiveNames = ttsModelRegistry.values
          .expand((voices) => voices)
          .map((m) => m.archiveName)
          .toSet();
      for (final entry in models.entries) {
        final lang = entry.key;
        final model = Map<String, dynamic>.from(entry.value as Map);
        final archiveName = model['archive_name'] as String;
        expect(model['downloaded_at'] as String, isA<String>());
        expect(allArchiveNames, contains(archiveName),
            reason: 'archive_name "$archiveName" for lang "$lang" '
                'not found in ttsModelRegistry');
      }
    });
  });

  group('migrateHive', () {
    late Directory tmp;
    late Box box;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('lexaway_migrate_');
      // `Hive.init` mutates a global singleton. Flutter tests run serially
      // by default and no sibling test in this file opens a Hive box, so
      // the rebind is safe. If that ever changes, switch to a scoped
      // `HiveInterface` or set `Hive.defaultDirectory` per-test.
      Hive.init(tmp.path);
      box = await Hive.openBox('migrate_test');
    });

    tearDown(() async {
      await box.close();
      await tmp.delete(recursive: true);
    });

    test('v1 fixture → v2: steps split + daily keys initialised', () async {
      // Seed the box with exactly the keys the v1 fixture carries.
      final v1 = _loadFixture('hive_v1.json');
      for (final entry in v1.entries) {
        await box.put(entry.key, entry.value);
      }
      expect(box.get(HiveKeys.hiveSchemaVersion), equals(1));
      expect(box.get('steps'), equals(1500));

      migrateHive(box);

      expect(box.get(HiveKeys.hiveSchemaVersion), equals(hiveSchemaVersion));
      expect(box.get(HiveKeys.stepsLifetime), equals(1500),
          reason: 'legacy lifetime should carry forward');
      expect(box.get(HiveKeys.stepsToday), equals(0));
      expect(box.get(HiveKeys.stepsDayKey), isA<String>());
      expect(box.containsKey('steps'), isFalse,
          reason: 'old bare key should be cleaned up');
      // Non-steps data is untouched.
      expect(box.get(HiveKeys.streak), equals(7));
      expect(box.get(HiveKeys.coins), equals(340));
    });

    test('is idempotent: running twice leaves v2 state intact', () async {
      final v1 = _loadFixture('hive_v1.json');
      for (final entry in v1.entries) {
        await box.put(entry.key, entry.value);
      }
      migrateHive(box);
      final afterFirst = {
        for (final k in box.keys) k: box.get(k),
      };
      migrateHive(box);
      final afterSecond = {
        for (final k in box.keys) k: box.get(k),
      };
      expect(afterSecond, equals(afterFirst));
    });
  });

  group('World state', () {
    late Map<String, dynamic> fixture;
    setUp(() => fixture = _loadFixture('hive_v2.json'));

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

      for (final idx in collected) {
        expect(allCoinIndices, contains(idx));
      }
    });
  });
}
