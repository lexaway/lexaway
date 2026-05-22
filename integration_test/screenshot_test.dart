import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:integration_test/integration_test.dart';

import 'package:lexaway/data/hive_keys.dart';
import 'package:lexaway/main.dart';
import 'package:lexaway/providers.dart';
import 'package:lexaway/screens/egg_selection_screen.dart';
import 'package:lexaway/screens/game_screen.dart';
import 'package:lexaway/screens/loading_screen.dart';
import 'package:lexaway/screens/pack_manager_screen.dart';
import 'package:lexaway/screens/settings_screen.dart';
import 'fakes.dart';
import 'screenshot_data.dart';

/// Pump [n] frames at ~60fps. Use instead of pumpAndSettle on screens with
/// continuous animations (Flame, TiledBackground) that never settle.
Future<void> pumpFrames(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// On Android (running via `flutter test`), screenshots go to device storage
/// so the host script can `adb pull` them. On iOS (running via `flutter drive`),
/// the test driver's onScreenshot callback handles file I/O.
const _androidScreenshotDir = '/sdcard/Download/lexaway_screenshots';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Box box;
  late Directory tmpDir;
  const lang = String.fromEnvironment('SCREENSHOT_LANG', defaultValue: 'en');
  final localeData = screenshotLocaleData[lang]!;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('lexaway_screenshots_');
    Hive.init('${tmpDir.path}/hive');
    box = await Hive.openBox('app');

    // Minimal Hive state — just enough for the app to boot.
    // Screens get their state progressively as we navigate.
    box.put(HiveKeys.gender, 'female');
    box.put(HiveKeys.uiLocale, lang);
  });

  tearDown(() async {
    await Hive.close();
    await tmpDir.delete(recursive: true);
  });

  testWidgets('App Store screenshots', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hiveBoxProvider.overrideWithValue(box),
          packsDirProvider.overrideWithValue('${tmpDir.path}/packs'),
          modelsDirProvider.overrideWithValue('${tmpDir.path}/models'),
          musicDirProvider.overrideWithValue('${tmpDir.path}/music'),
          tmpDirProvider.overrideWithValue('${tmpDir.path}/tmp'),
          activePackProvider.overrideWith(FakeActivePackNotifier.new),
          localPacksProvider.overrideWith(FakeLocalPacksNotifier.new),
          manifestProvider.overrideWith((_) async => localeData.manifest),
        ],
        child: const LexawayApp(),
      ),
    );

    // On Android, convert the Flutter surface so screenshots can be captured.
    // This requires the native integration_test plugin (loaded by `flutter test`,
    // but NOT by `flutter drive` — which is why Android uses `flutter test`).
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
    }

    // No active pack, no character → router redirects /loading → /packs
    await pumpFrames(tester, 30);

    // Wire up locale-specific data into fakes
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    final fakePack =
        container.read(activePackProvider.notifier) as FakeActivePackNotifier;
    fakePack.localeData = localeData;

    final fakeLocalPacks =
        container.read(localPacksProvider.notifier) as FakeLocalPacksNotifier;
    fakeLocalPacks.setPacks(localeData.localPacks);

    // On Android, also write PNGs to device storage so the host can adb pull.
    // On iOS, the test driver's onScreenshot callback handles file I/O.
    Future<void> screenshot(String name) async {
      await binding.takeScreenshot(name);
      if (Platform.isAndroid) {
        final screenshots = binding.reportData!['screenshots'] as List;
        final entry = screenshots.last as Map<String, dynamic>;
        final bytes = entry['bytes'] as List<int>;
        final dir = Directory('$_androidScreenshotDir/$lang');
        await dir.create(recursive: true);
        await File('${dir.path}/$name.png').writeAsBytes(bytes);
      }
    }

    // Helper to navigate via GoRouter
    void navigate(String path) {
      final ctx = tester.element(find.byType(Scaffold).first);
      GoRouter.of(ctx).go(path);
    }

    // --- 1. Pack Manager ---
    // We land here naturally since there are no active questions.
    expect(find.byType(PackManagerScreen), findsOneWidget);
    await screenshot('01_packs');

    // --- 2. Settings ---
    navigate('/settings');
    await pumpFrames(tester, 30);
    expect(find.byType(SettingsScreen), findsOneWidget);
    await screenshot('02_settings');

    // --- 3. Egg Selection ---
    // Activate the pack so the router sees questions, but no character yet.
    fakePack.activate();
    // Router now has questions + no character → allows /hatch
    navigate('/hatch');
    await pumpFrames(tester, 90);
    expect(find.byType(EggSelectionScreen), findsOneWidget);
    await screenshot('03_egg_selection');

    // --- 4. Game ---
    // Seed character + world state so the game screen can render.
    box.put(HiveKeys.coins, 42);
    box.put(HiveKeys.streak, 7);
    box.put(HiveKeys.character(localeData.characterKey), 'female/doux');
    box.put(HiveKeys.world(localeData.activeLang), {
      'seed': 12345,
      'extensions': 0,
      'scroll_offset': 150.0,
      'collected_coins': <int>[],
    });
    // PackManagerScreen reads characterProvider(lang) for every pack tile in
    // step 1, caching null before we seed the box here. Invalidate so the
    // /game redirect re-reads the (now non-null) value from box.
    container.invalidate(characterProvider(localeData.activeLang));
    navigate('/game');
    // Give Flame time to load sprites and render the world.
    await pumpFrames(tester, 180);
    expect(find.byType(GameScreen), findsOneWidget);
    await screenshot('04_game');

    // --- 5. Loading Screen ---
    // Put the provider back into loading state so the router redirects to /loading.
    fakePack.setLoading();
    navigate('/loading');
    await pumpFrames(tester, 60);
    expect(find.byType(LoadingScreen), findsOneWidget);
    await screenshot('05_loading');
  });
}
