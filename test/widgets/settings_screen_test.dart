import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:lexaway/data/hive_keys.dart';
import 'package:lexaway/providers.dart';
import 'package:lexaway/l10n/app_localizations.dart';
import 'package:lexaway/screens/settings_screen.dart';

void main() {
  late Box box;

  setUp(() async {
    // Use an in-memory Hive box to avoid file I/O futures that can never
    // complete inside Flutter's FakeAsync test zone, which would cause
    // pumpAndSettle() — and even post-test cleanup — to hang forever.
    box = await Hive.openBox('settings', bytes: Uint8List(0));
  });

  tearDown(() async {
    await box.close();
  });

  Widget buildApp({Box? hiveBox}) {
    return ProviderScope(
      overrides: [
        hiveBoxProvider.overrideWithValue(hiveBox ?? box),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) {
            final inherited = MediaQuery.of(context);
            return MediaQuery(
              data: inherited.copyWith(disableAnimations: true),
              child: Navigator(
                onGenerateRoute: (_) => MaterialPageRoute(
                  builder: (_) => const Scaffold(),
                ),
                onGenerateInitialRoutes: (navigator, initialRoute) => [
                  MaterialPageRoute(builder: (_) => const Scaffold()),
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> pumpSettings(WidgetTester tester, {Box? hiveBox}) async {
    // Settings is a long ListView. Force a tall surface so virtualized
    // children below the fold (daily-goal tiles, reminder toggle) are
    // realised in the widget tree without per-test scrolling.
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    await tester.pumpWidget(buildApp(hiveBox: hiveBox));
    await tester.pumpAndSettle();
  }

  group('SettingsScreen', () {
    testWidgets('renders title', (tester) async {
      await pumpSettings(tester);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('renders all volume sliders', (tester) async {
      await pumpSettings(tester);
      expect(find.text('Master'), findsOneWidget);
      expect(find.text('SFX'), findsOneWidget);
      expect(find.text('Music'), findsOneWidget);
      expect(find.text('Voice'), findsOneWidget);
    });

    testWidgets('renders haptics toggle', (tester) async {
      await pumpSettings(tester);
      expect(find.text('Haptics'), findsOneWidget);
      // Haptics, Auto-play voice, and Reminder toggles.
      expect(find.byType(Switch), findsNWidgets(3));
    });

    testWidgets('sliders default correctly', (tester) async {
      await pumpSettings(tester);

      final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
      expect(sliders.length, 4);
      expect(sliders[0].value, 1.0);  // master
      expect(sliders[1].value, 0.5);  // sfx
      expect(sliders[2].value, 0.0);  // bgm (opt-in)
      expect(sliders[3].value, 1.0);  // tts
    });

    testWidgets('sliders read initial values from Hive', (tester) async {
      box.put(HiveKeys.volMaster, 0.3);
      box.put(HiveKeys.volSfx, 0.5);
      box.put(HiveKeys.volBgm, 0.2);
      box.put(HiveKeys.volTts, 0.7);

      await pumpSettings(tester);

      final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
      expect(sliders[0].value, closeTo(0.3, 0.01));
      expect(sliders[1].value, closeTo(0.5, 0.01));
      expect(sliders[2].value, closeTo(0.2, 0.01));
      expect(sliders[3].value, closeTo(0.7, 0.01));
    });

    testWidgets('haptics toggle defaults to on', (tester) async {
      await pumpSettings(tester);

      final toggle = tester.widget<Switch>(find.byType(Switch).first);
      expect(toggle.value, isTrue);
    });

    testWidgets('haptics toggle reads initial value from Hive', (tester) async {
      box.put(HiveKeys.haptics, false);

      await pumpSettings(tester);

      final toggle = tester.widget<Switch>(find.byType(Switch).first);
      expect(toggle.value, isFalse);
    });

    testWidgets('toggling haptics persists to Hive', (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(box.get(HiveKeys.haptics), isFalse);
    });

    testWidgets('dragging master slider updates state and persists',
        (tester) async {
      await pumpSettings(tester);

      final masterSlider = find.byType(Slider).first;
      final sliderCenter = tester.getCenter(masterSlider);
      await tester.drag(masterSlider, Offset(-sliderCenter.dx * 0.3, 0));
      await tester.pumpAndSettle();

      final slider = tester.widget<Slider>(masterSlider);
      expect(slider.value, lessThan(1.0));
      expect(box.get(HiveKeys.volMaster) as double, lessThan(1.0));
    });

    testWidgets('shows section headers', (tester) async {
      await pumpSettings(tester);
      expect(find.text('Sound'), findsOneWidget);
      expect(find.text('Gameplay'), findsOneWidget);
    });

    testWidgets('back button exists', (tester) async {
      await pumpSettings(tester);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('daily goal tiles render one per preset with time labels',
        (tester) async {
      await pumpSettings(tester);
      // Parallel-list-drift guard: if dailyGoalPresets and its minutes/tier
      // fields ever fall out of sync, one of these asserts fails before the
      // UI ships a mislabelled tile.
      expect(find.text('~1 min'), findsOneWidget);
      expect(find.text('~2 min'), findsOneWidget);
      expect(find.text('~5 min'), findsOneWidget);
      expect(find.text('~10 min'), findsOneWidget);
      expect(find.text('Quick'), findsOneWidget);
      expect(find.text('Short'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Long'), findsOneWidget);
    });

    testWidgets('tapping a goal tile persists the step count to Hive',
        (tester) async {
      await pumpSettings(tester);
      final tile = find.text('~5 min');
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(box.get(HiveKeys.dailyGoal), equals(500));
    });

    testWidgets('stale stored goal snaps to nearest preset on load',
        (tester) async {
      // Pre-refactor users may have 50 persisted. Build() should snap to
      // the closest surviving preset (100) and rewrite Hive so the UI
      // always has a highlighted tile.
      box.put(HiveKeys.dailyGoal, 50);
      await pumpSettings(tester);
      expect(box.get(HiveKeys.dailyGoal), equals(100));
    });
  });
}
