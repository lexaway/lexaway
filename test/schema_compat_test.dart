import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:lexaway/data/hive_keys.dart';
import 'package:lexaway/data/pack_manager.dart';
import 'package:lexaway/data/tts_manager.dart' show kBaselineVoiceCatalog;
import 'package:lexaway/game/world/world_generator.dart';
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

  group('Hive box v2 compatibility (legacy snapshot)', () {
    late Map<String, dynamic> fixture;
    setUp(() => fixture = _loadFixture('hive_v2.json'));

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
      final allArchiveNames = kBaselineVoiceCatalog.values
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
                'not found in kBaselineVoiceCatalog');
      }
    });
  });

  group('Hive box v3 compatibility (current)', () {
    late Map<String, dynamic> fixture;
    setUp(() => fixture = _loadFixture('hive_v3.json'));

    test('fixture version matches current hiveSchemaVersion', () {
      expect(fixture['hive_schema_version'], equals(hiveSchemaVersion));
    });

    test('per-language world key uses HiveKeys.world(lang) shape', () {
      // v3 split the global 'world' into 'world_<lang>'. The fixture should
      // carry the per-language form and no legacy global key.
      expect(fixture.containsKey('world'), isFalse,
          reason: 'legacy global world key should be gone in v3');
      expect(fixture[HiveKeys.world('fra')], isA<Map>());
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

    test('v1 fixture → current: steps split + world re-keyed by lang', () async {
      // Seed the box with exactly the keys the v1 fixture carries.
      final v1 = _loadFixture('hive_v1.json');
      for (final entry in v1.entries) {
        await box.put(entry.key, entry.value);
      }
      expect(box.get(HiveKeys.hiveSchemaVersion), equals(1));
      expect(box.get('steps'), equals(1500));
      expect(box.get('world'), isA<Map>());

      migrateHive(box);

      expect(box.get(HiveKeys.hiveSchemaVersion), equals(hiveSchemaVersion));
      // v1 → v2: steps shape change.
      expect(box.get(HiveKeys.stepsLifetime), equals(1500),
          reason: 'legacy lifetime should carry forward');
      expect(box.get(HiveKeys.stepsToday), equals(0));
      expect(box.get(HiveKeys.stepsDayKey), isA<String>());
      expect(box.containsKey('steps'), isFalse,
          reason: 'old bare key should be cleaned up');
      // v2 → v3: world re-keyed by lang via lastUsed pack ID.
      expect(box.containsKey('world'), isFalse,
          reason: 'legacy global world key should be removed');
      final reKeyed = box.get(HiveKeys.world('fra')) as Map?;
      expect(reKeyed, isNotNull,
          reason: 'world should land under the active pack lang');
      expect(reKeyed!['seed'], equals(42));
      expect(reKeyed['scroll_offset'], equals(1234.5));
      // Non-migrated data is untouched.
      expect(box.get(HiveKeys.streak), equals(7));
      expect(box.get(HiveKeys.coins), equals(340));
    });

    test('v2 → v3: world re-keyed by active pack lang', () async {
      final v2 = _loadFixture('hive_v2.json');
      for (final entry in v2.entries) {
        await box.put(entry.key, entry.value);
      }
      expect(box.get(HiveKeys.hiveSchemaVersion), equals(2));
      expect(box.get('world'), isA<Map>());

      migrateHive(box);

      expect(box.get(HiveKeys.hiveSchemaVersion), equals(hiveSchemaVersion));
      expect(box.containsKey('world'), isFalse);
      final reKeyed = box.get(HiveKeys.world('fra')) as Map?;
      expect(reKeyed, isNotNull);
      expect(reKeyed!['seed'], equals(42));
    });

    test('v2 → v3: world dropped when lastUsed is missing', () async {
      final v2 = _loadFixture('hive_v2.json');
      for (final entry in v2.entries) {
        await box.put(entry.key, entry.value);
      }
      // Simulate a user who never opened a pack — no attribution possible.
      await box.delete(HiveKeys.lastUsed);

      migrateHive(box);

      expect(box.containsKey('world'), isFalse,
          reason: 'unattributable legacy world should be dropped');
      // No per-lang world should be created either.
      final perLangKeys = box.keys.where((k) =>
          k is String && k.startsWith('world_'));
      expect(perLangKeys, isEmpty);
    });

    test('v2 → v3: corrupt non-Map legacy world is dropped', () async {
      await box.put(HiveKeys.hiveSchemaVersion, 2);
      await box.put('world', 'definitely-not-a-map');
      await box.put(HiveKeys.lastUsed, 'eng-fra');

      migrateHive(box);

      expect(box.containsKey('world'), isFalse);
      expect(box.containsKey(HiveKeys.world('fra')), isFalse,
          reason: 'corrupt-by-shape worlds should not be carried forward');
    });

    test('v2 → v3: unparseable lastUsed drops the world', () async {
      await box.put(HiveKeys.hiveSchemaVersion, 2);
      await box.put('world', {'seed': 1, 'extensions': 0,
          'scroll_offset': 0.0, 'collected_coins': <int>[]});
      // Missing the '<from>-<lang>' shape — `parsePackId` throws.
      await box.put(HiveKeys.lastUsed, 'garbage');

      migrateHive(box);

      expect(box.containsKey('world'), isFalse);
      final perLangKeys = box.keys.where((k) =>
          k is String && k.startsWith('world_'));
      expect(perLangKeys, isEmpty);
    });

    test('is idempotent: running twice leaves migrated state intact', () async {
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
    setUp(() => fixture = _loadFixture('hive_v3.json'));

    test('world state fixture has expected keys', () {
      final world = Map<String, dynamic>.from(fixture[HiveKeys.world('fra')] as Map);
      expect(world['seed'], isA<int>());
      expect((world['scroll_offset'] as num).toDouble(), isA<double>());
      expect(world['collected_coins'], isA<List>());
      expect(world['extensions'], isA<int>());
    });

    test('world regenerates deterministically from seed', () {
      final world = Map<String, dynamic>.from(fixture[HiveKeys.world('fra')] as Map);
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

  });
}
