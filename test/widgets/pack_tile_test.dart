import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lexaway/data/pack_manager.dart';
import 'package:lexaway/widgets/pack_tile.dart';
import 'package:lexaway/l10n/app_localizations.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('PackTile', () {
    Widget wrap(Widget child) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );
    }

    const fraPack = PackInfo(lang: 'fra', name: 'French', flag: '🇫🇷');
    const localPack = LocalPack(
      lang: 'fra',
      schemaVersion: 1,
      builtAt: '2025-01-01T00:00:00Z',
      sizeBytes: 5 * 1024 * 1024, // 5 MB
    );

    PackTile buildTile({
      PackInfo pack = fraPack,
      LocalPack? local,
      double? packProgress,
      double? voiceProgress,
      bool voiceDownloaded = false,
      bool hasCharacter = false,
      VoidCallback? onDownload,
      VoidCallback? onDownloadVoice,
      VoidCallback? onDelete,
      VoidCallback? onDeleteVoice,
      VoidCallback? onSelect,
    }) {
      return PackTile(
        pack: pack,
        local: local,
        packProgress: packProgress,
        voiceProgress: voiceProgress,
        voiceDownloaded: voiceDownloaded,
        hasCharacter: hasCharacter,
        onDownload: onDownload ?? () {},
        onDownloadVoice: onDownloadVoice ?? () {},
        onDelete: onDelete ?? () {},
        onDeleteVoice: onDeleteVoice ?? () {},
        onSelect: onSelect ?? () {},
      );
    }

    testWidgets('shows language badge', (tester) async {
      await tester.pumpWidget(wrap(buildTile()));
      await tester.pumpAndSettle();
      expect(find.text('FRA'), findsOneWidget);
    });

    testWidgets('shows pack name', (tester) async {
      await tester.pumpWidget(wrap(buildTile()));
      await tester.pumpAndSettle();
      expect(find.text('French'), findsOneWidget);
    });

    // -- Not downloaded state --

    testWidgets('shows download buttons when not downloaded', (tester) async {
      await tester.pumpWidget(wrap(buildTile(local: null)));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.download_rounded), findsWidgets);
    });

    testWidgets('fires onDownload when tapping download icon', (tester) async {
      var downloaded = false;
      await tester.pumpWidget(wrap(buildTile(
        local: null,
        onDownload: () => downloaded = true,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.download_rounded).first);
      expect(downloaded, isTrue);
    });

    // -- Downloaded state --

    testWidgets('shows check icon when downloaded', (tester) async {
      await tester.pumpWidget(wrap(buildTile(local: localPack)));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle), findsWidgets);
    });

    testWidgets('shows delete button on sentences row when downloaded',
        (tester) async {
      await tester.pumpWidget(wrap(buildTile(local: localPack)));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.delete_outline), findsWidgets);
    });

    testWidgets('fires onDelete when tapping sentences delete',
        (tester) async {
      var deleted = false;
      await tester.pumpWidget(wrap(buildTile(
        local: localPack,
        onDelete: () => deleted = true,
      )));
      await tester.pumpAndSettle();

      // First delete icon is the sentences row
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      expect(deleted, isTrue);
    });

    testWidgets('shows file size when downloaded', (tester) async {
      await tester.pumpWidget(wrap(buildTile(local: localPack)));
      await tester.pumpAndSettle();
      expect(find.text('5.0 MB'), findsOneWidget);
    });

    // -- Downloading state --

    testWidgets('shows spinner during pack download', (tester) async {
      await tester.pumpWidget(wrap(buildTile(packProgress: 0.5)));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    // -- Voice row (fra has TTS support) --

    testWidgets('shows voice row for supported languages', (tester) async {
      await tester.pumpWidget(wrap(buildTile()));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    });

    testWidgets('hides voice row for unsupported languages', (tester) async {
      const unsupported = PackInfo(lang: 'zzz', name: 'Unknown', flag: '?');
      await tester.pumpWidget(wrap(buildTile(pack: unsupported)));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
    });

    testWidgets('voice download is disabled when sentences not installed',
        (tester) async {
      var voiceDownloaded = false;
      await tester.pumpWidget(wrap(buildTile(
        local: null,
        voiceDownloaded: false,
        onDownloadVoice: () => voiceDownloaded = true,
      )));
      await tester.pumpAndSettle();

      // Voice download icon should exist but be disabled
      final downloadIcons = find.byIcon(Icons.download_rounded);
      await tester.tap(downloadIcons.last);
      expect(voiceDownloaded, isFalse);
    });

    testWidgets('shows voice download button when pack installed but no voice',
        (tester) async {
      var voiceDownloaded = false;
      await tester.pumpWidget(wrap(buildTile(
        local: localPack,
        voiceDownloaded: false,
        onDownloadVoice: () => voiceDownloaded = true,
      )));
      await tester.pumpAndSettle();

      final downloadIcons = find.byIcon(Icons.download_rounded);
      await tester.tap(downloadIcons.last);
      expect(voiceDownloaded, isTrue);
    });

    testWidgets('fires onDeleteVoice when tapping voice trash', (tester) async {
      var voiceDeleted = false;
      await tester.pumpWidget(wrap(buildTile(
        local: localPack,
        voiceDownloaded: true,
        onDeleteVoice: () => voiceDeleted = true,
      )));
      await tester.pumpAndSettle();

      // Last delete icon is the voice row's
      final deleteIcons = find.byIcon(Icons.delete_outline);
      await tester.tap(deleteIcons.last);
      expect(voiceDeleted, isTrue);
    });

    // -- Action button --

    testWidgets('shows Start when no character', (tester) async {
      await tester.pumpWidget(wrap(buildTile(hasCharacter: false)));
      await tester.pumpAndSettle();
      expect(find.text('Start'), findsOneWidget);
    });

    testWidgets('shows Continue when character exists', (tester) async {
      await tester.pumpWidget(wrap(buildTile(hasCharacter: true)));
      await tester.pumpAndSettle();
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('action button fires onSelect when downloaded',
        (tester) async {
      var selected = false;
      await tester.pumpWidget(wrap(buildTile(
        local: localPack,
        onSelect: () => selected = true,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start'));
      expect(selected, isTrue);
    });

    testWidgets('action button is disabled when not downloaded',
        (tester) async {
      var selected = false;
      await tester.pumpWidget(wrap(buildTile(
        local: null,
        onSelect: () => selected = true,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start'));
      expect(selected, isFalse);
    });
  });
}
