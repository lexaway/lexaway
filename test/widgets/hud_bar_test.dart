import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:lexaway/data/hive_keys.dart';
import 'package:lexaway/providers.dart';
import 'package:lexaway/widgets/hud_bar.dart';

void main() {
  late Box box;

  setUp(() async {
    box = await Hive.openBox('streak', bytes: Uint8List(0));
  });

  tearDown(() async {
    await box.close();
  });

  Widget buildApp({Box? hiveBox}) {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: HudBar()),
        ),
        GoRoute(path: '/packs', builder: (_, __) => const Scaffold()),
        GoRoute(path: '/settings', builder: (_, __) => const Scaffold()),
      ],
    );

    return ProviderScope(
      overrides: [
        hiveBoxProvider.overrideWithValue(hiveBox ?? box),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  group('HudBar', () {
    testWidgets('displays coin count from Hive', (tester) async {
      box.put(HiveKeys.coins, 42);
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('defaults to 0 coins', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('shows language icon button', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.language), findsOneWidget);
    });

    testWidgets('shows settings icon button', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('tapping language icon navigates to /packs', (tester) async {
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const Scaffold(body: HudBar()),
          ),
          GoRoute(
            path: '/packs',
            builder: (_, __) => const Scaffold(body: Text('PACKS_SCREEN')),
          ),
          GoRoute(path: '/settings', builder: (_, __) => const Scaffold()),
        ],
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [hiveBoxProvider.overrideWithValue(box)],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.language));
      await tester.pumpAndSettle();

      expect(find.text('PACKS_SCREEN'), findsOneWidget);
    });

    testWidgets('tapping settings icon navigates to /settings', (tester) async {
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const Scaffold(body: HudBar()),
          ),
          GoRoute(path: '/packs', builder: (_, __) => const Scaffold()),
          GoRoute(
            path: '/settings',
            builder: (_, __) =>
                const Scaffold(body: Text('SETTINGS_SCREEN')),
          ),
        ],
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [hiveBoxProvider.overrideWithValue(box)],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(find.text('SETTINGS_SCREEN'), findsOneWidget);
    });

    testWidgets('updates when coins change', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      expect(find.text('0'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(HudBar)),
      );
      container.read(coinProvider.notifier).add(10);
      await tester.pumpAndSettle();

      expect(find.text('10'), findsOneWidget);
    });
  });
}
