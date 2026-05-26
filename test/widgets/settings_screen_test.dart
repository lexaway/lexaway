import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:lexaway/data/hive_keys.dart';
import 'package:lexaway/l10n/app_localizations.dart';
import 'package:lexaway/providers.dart';
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
                  MaterialPageRoute(
                    // SettingsScreen is hosted inside LexawayBottomSheet
                    // in the real app, which supplies the Material ancestor
                    // its Sliders/Switches need. Mirror that here.
                    builder: (_) => const Scaffold(body: SettingsScreen()),
                  ),
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
    // children below the fold are realised in the widget tree without
    // per-test scrolling.
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
      // Haptics, Auto-play voice, and Vocab-flashcard notifications toggles.
      expect(find.byType(Switch), findsNWidgets(3));
    });

    testWidgets('sliders default correctly', (tester) async {
      await pumpSettings(tester);

      final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
      expect(sliders.length, 5);
      expect(sliders[0].value, 1.0);  // master
      expect(sliders[1].value, 0.5);  // sfx
      expect(sliders[2].value, 0.5);  // bgm
      expect(sliders[3].value, 1.0);  // tts
      expect(sliders[4].value, 3.0);  // notifications per-day
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

    testWidgets('close button exists', (tester) async {
      await pumpSettings(tester);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });
}
