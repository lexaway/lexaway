import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

import 'package:lexaway/data/hive_migration.dart';
import 'package:lexaway/data/pack_manager.dart';
import 'package:lexaway/data/question_source.dart';
import 'package:lexaway/providers.dart';

/// Boots the provider tree with persisted data from each shipped schema version.
/// Catches provider crashes, Hive cast mismatches, and initialization failures —
/// the exact class of bug that bricks users on update.
///
/// Uses ProviderContainer (no widget tree) to avoid continuous-animation timers
/// that prevent headless tests from completing. The router and widget layer are
/// thin; the provider layer is where bricking bugs live.
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final snapshots = {
    'v1': 'test/fixtures/hive_v1.json',
  };

  for (final entry in snapshots.entries) {
    test('Provider tree boots with ${entry.key} data without crashing',
        () async {
      final tmpDir =
          await Directory.systemTemp.createTemp('lexaway_snapshot_test_');
      try {
        Hive.init('${tmpDir.path}/hive');
        final box = await Hive.openBox('app');

        // Load fixture and seed every key into the box.
        final fixtureJson = jsonDecode(File(entry.value).readAsStringSync())
            as Map<String, dynamic>;
        for (final kv in fixtureJson.entries) {
          await box.put(kv.key, kv.value);
        }

        // Run migrations (exercises the migration path from old data).
        migrateHive(box);

        // Parse manifest from the fixture's cached manifest.
        final manifestJson = jsonDecode(fixtureJson['manifest_cache'] as String)
            as Map<String, dynamic>;
        final manifest = Manifest.fromJson(manifestJson);

        final container = ProviderContainer(
          overrides: [
            hiveBoxProvider.overrideWithValue(box),
            packsDirProvider.overrideWithValue('${tmpDir.path}/packs'),
            modelsDirProvider.overrideWithValue('${tmpDir.path}/models'),
            tmpDirProvider.overrideWithValue('${tmpDir.path}/tmp'),
            manifestProvider.overrideWith((_) async => manifest),
            activePackProvider.overrideWith(_NullActivePackNotifier.new),
            localPacksProvider.overrideWith(_EmptyLocalPacksNotifier.new),
          ],
        );

        try {
          // Read every settings provider that casts from Hive — these are the
          // exact casts that crash on launch when old data doesn't match.
          container.read(localeProvider);
          container.read(fontProvider);
          container.read(masterVolumeProvider);
          container.read(sfxVolumeProvider);
          container.read(ttsVolumeProvider);
          container.read(hapticsEnabledProvider);
          container.read(genderProvider);
          container.read(autoPlayTtsProvider);
          container.read(streakProvider);
          container.read(bestStreakProvider);
          container.read(coinProvider);
          container.read(stepsProvider);

          // Read the character provider — a .family provider that casts
          // from Hive with `as String?`.
          container.read(characterProvider('fra'));

          // Read the world state repository — exercises the world state cast.
          final repo = container.read(worldStateRepositoryProvider);
          repo.load();

          // Read packs-related providers.
          container.read(packManagerProvider);
          final activePack = await container.read(activePackProvider.future);
          expect(activePack, isNull); // our fake returns null

          final localPacks = await container.read(localPacksProvider.future);
          expect(localPacks, isEmpty); // our fake returns empty

          final fetchedManifest = await container.read(manifestProvider.future);
          expect(fetchedManifest.packs, isNotEmpty);
        } finally {
          container.dispose();
        }

        await Hive.close();
      } finally {
        await tmpDir.delete(recursive: true);
      }
    });
  }
}

/// Returns null — no active pack.
class _NullActivePackNotifier extends ActivePackNotifier {
  @override
  Future<QuestionSource?> build() async => null;
}

/// Returns empty — no local packs installed.
class _EmptyLocalPacksNotifier extends LocalPacksNotifier {
  @override
  Future<Map<String, LocalPack>> build() async => {};
}
