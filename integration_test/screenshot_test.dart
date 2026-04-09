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
          tmpDirProvider.overrideWithValue('${tmpDir.path}/tmp'),
          activePackProvider.overrideWith(FakeActivePackNotifier.new),
          localPacksProvider.overrideWith(FakeLocalPacksNotifier.new),
          manifestProvider.overrideWith((_) async => localeData.manifest),
        ],
        child: const LexawayApp(),
      ),
    );

    // No active pack, no character → router redirects /loading → /packs
    await pumpFrames(tester, 30);

    // Wire up locale-specific data into fakes
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    final fakePack =
        container.read(activePackProvider.notifier) as FakeActivePackNotifier;
    fakePack.setLocaleData(localeData);

    final fakeLocalPacks =
        container.read(localPacksProvider.notifier) as FakeLocalPacksNotifier;
    fakeLocalPacks.setPacks(localeData.localPacks);

    // Helper to navigate via GoRouter
    void navigate(String path) {
      final ctx = tester.element(find.byType(Scaffold).first);
      GoRouter.of(ctx).go(path);
    }

    // --- 1. Pack Manager ---
    // We land here naturally since there are no active questions.
    expect(find.byType(PackManagerScreen), findsOneWidget);
    await binding.takeScreenshot('01_packs');

    // --- 2. Settings ---
    navigate('/settings');
    await pumpFrames(tester, 30);
    expect(find.byType(SettingsScreen), findsOneWidget);
    await binding.takeScreenshot('02_settings');

    // --- 3. Egg Selection ---
    // Activate the pack so the router sees questions, but no character yet.
    fakePack.activate();
    // Router now has questions + no character → allows /hatch
    navigate('/hatch');
    await pumpFrames(tester, 90);
    expect(find.byType(EggSelectionScreen), findsOneWidget);
    await binding.takeScreenshot('03_egg_selection');

    // --- 4. Game ---
    // Seed character + world state so the game screen can render.
    box.put(HiveKeys.coins, 42);
    box.put(HiveKeys.streak, 7);
    box.put(HiveKeys.character(localeData.characterKey), 'female/doux');
    box.put(HiveKeys.world, {
      'seed': 12345,
      'extensions': 0,
      'scroll_offset': 150.0,
      'collected_coins': <int>[],
    });
    navigate('/game');
    // Give Flame time to load sprites and render the world.
    await pumpFrames(tester, 180);
    expect(find.byType(GameScreen), findsOneWidget);
    await binding.takeScreenshot('04_game');

    // --- 5. Loading Screen ---
    // Put the provider back into loading state so the router redirects to /loading.
    fakePack.setLoading();
    navigate('/loading');
    await pumpFrames(tester, 60);
    expect(find.byType(LoadingScreen), findsOneWidget);
    await binding.takeScreenshot('05_loading');
  });
}
