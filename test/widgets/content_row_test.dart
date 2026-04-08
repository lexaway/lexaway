import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lexaway/widgets/content_row.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('ContentRow', () {
    Widget wrap(Widget child) {
      return MaterialApp(home: Scaffold(body: child));
    }

    ContentRow buildRow({
      String label = 'Sentences',
      String? sizeText,
      bool downloaded = false,
      double? progress,
      VoidCallback? onDownload,
      VoidCallback? onDelete,
    }) {
      return ContentRow(
        icon: Icons.text_snippet_outlined,
        label: label,
        sizeText: sizeText,
        downloaded: downloaded,
        progress: progress,
        onDownload: onDownload,
        onDelete: onDelete,
      );
    }

    testWidgets('displays label', (tester) async {
      await tester.pumpWidget(wrap(buildRow(label: 'Sentences')));
      expect(find.text('Sentences'), findsOneWidget);
    });

    testWidgets('shows size text when provided', (tester) async {
      await tester.pumpWidget(wrap(buildRow(sizeText: '12.3 MB')));
      expect(find.text('12.3 MB'), findsOneWidget);
    });

    testWidgets('hides size text when null', (tester) async {
      await tester.pumpWidget(wrap(buildRow(sizeText: null)));
      expect(find.text('12.3 MB'), findsNothing);
    });

    testWidgets('shows progress bar when progress is set', (tester) async {
      await tester.pumpWidget(wrap(buildRow(progress: 0.5)));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('hides progress bar when progress is null', (tester) async {
      await tester.pumpWidget(wrap(buildRow(progress: null)));
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('shows check icon when downloaded', (tester) async {
      await tester.pumpWidget(wrap(buildRow(downloaded: true)));
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('shows content icon when not downloaded', (tester) async {
      await tester.pumpWidget(wrap(buildRow(downloaded: false)));
      expect(find.byIcon(Icons.text_snippet_outlined), findsOneWidget);
    });

    testWidgets('shows spinner during download instead of icons',
        (tester) async {
      await tester.pumpWidget(wrap(buildRow(progress: 0.5)));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.byIcon(Icons.text_snippet_outlined), findsNothing);
    });

    testWidgets('shows download button when not downloaded', (tester) async {
      await tester.pumpWidget(wrap(buildRow(downloaded: false)));
      expect(find.byIcon(Icons.download_rounded), findsOneWidget);
    });

    testWidgets('shows trash icon when downloaded', (tester) async {
      await tester.pumpWidget(wrap(buildRow(downloaded: true)));
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('hides action buttons during download', (tester) async {
      await tester.pumpWidget(wrap(buildRow(progress: 0.5)));
      expect(find.byIcon(Icons.download_rounded), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('fires onDownload when tapping download', (tester) async {
      var downloaded = false;
      await tester.pumpWidget(wrap(buildRow(
        downloaded: false,
        onDownload: () => downloaded = true,
      )));
      await tester.tap(find.byIcon(Icons.download_rounded));
      expect(downloaded, isTrue);
    });

    testWidgets('fires onDelete when tapping trash', (tester) async {
      var deleted = false;
      await tester.pumpWidget(wrap(buildRow(
        downloaded: true,
        onDelete: () => deleted = true,
      )));
      await tester.tap(find.byIcon(Icons.delete_outline));
      expect(deleted, isTrue);
    });
  });
}
