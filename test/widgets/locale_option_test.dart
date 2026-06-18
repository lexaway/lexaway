import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexaway/widgets/locale_option.dart';

void main() {
  group('LocaleOption', () {
    Widget wrap(Widget child) {
      return MaterialApp(home: Scaffold(body: child));
    }

    testWidgets('shows label text', (tester) async {
      await tester.pumpWidget(wrap(
        LocaleOption(label: 'English', selected: false, onTap: () {}),
      ));

      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('shows subtitle when provided', (tester) async {
      await tester.pumpWidget(wrap(
        LocaleOption(
          label: 'Français',
          subtitle: 'French',
          selected: false,
          onTap: () {},
        ),
      ));

      expect(find.text('Français'), findsOneWidget);
      expect(find.text('French'), findsOneWidget);
    });

    testWidgets('hides subtitle when null', (tester) async {
      await tester.pumpWidget(wrap(
        LocaleOption(label: 'English', selected: false, onTap: () {}),
      ));

      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('shows check icon when selected', (tester) async {
      await tester.pumpWidget(wrap(
        LocaleOption(label: 'English', selected: true, onTap: () {}),
      ));

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('hides check icon when not selected', (tester) async {
      await tester.pumpWidget(wrap(
        LocaleOption(label: 'English', selected: false, onTap: () {}),
      ));

      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('uses bold text when selected', (tester) async {
      await tester.pumpWidget(wrap(
        LocaleOption(label: 'English', selected: true, onTap: () {}),
      ));

      final text = tester.widget<Text>(find.text('English'));
      expect(text.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('fires onTap callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(
        LocaleOption(label: 'English', selected: false, onTap: () => tapped = true),
      ));

      await tester.tap(find.text('English'));
      expect(tapped, isTrue);
    });
  });
}
