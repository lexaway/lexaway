import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lexaway/data/pack_manager.dart';
import 'package:lexaway/data/tts_manager.dart';
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

    const fraPack = PackInfo(
      lang: 'fra',
      fromLang: 'eng',
      name: 'French',
      flag: '🇫🇷',
      builtAt: '2025-01-01T00:00:00Z',
      schemaVersion: 1,
    );
    const localPack = LocalPack(
      lang: 'fra',
      fromLang: 'eng',
      schemaVersion: 1,
      builtAt: '2025-01-01T00:00:00Z',
      sizeBytes: 5 * 1024 * 1024, // 5 MB
    );

    const fraVoiceModels = [
      TtsModelInfo(modelId: 'siwis', displayName: 'Siwis', archiveName: 'vits-piper-fr_FR-siwis-medium', onnxFile: 'fr_FR-siwis-medium.onnx', approximateSizeMB: 61),
      TtsModelInfo(modelId: 'tom', displayName: 'Tom', archiveName: 'vits-piper-fr_FR-tom-medium', onnxFile: 'fr_FR-tom-medium.onnx', approximateSizeMB: 61),
    ];

    PackTile buildTile({
      PackInfo pack = fraPack,
      LocalPack? local,
      PackUpdateStatus? status,
      double? packProgress,
      double? voiceProgress,
      List<TtsModelInfo> voiceModels = fraVoiceModels,
      String? downloadedModelId,
      bool hasCharacter = false,
      VoidCallback? onDownload,
      VoidCallback? onUpdate,
      void Function(String)? onDownloadVoice,
      VoidCallback? onDelete,
      VoidCallback? onDeleteVoice,
      VoidCallback? onSelect,
    }) {
      return PackTile(
        pack: pack,
        local: local,
        packStatus: status ?? packUpdateStatus(pack, local),
        packProgress: packProgress,
        voiceProgress: voiceProgress,
        voiceModels: voiceModels,
        downloadedModelId: downloadedModelId,
        hasCharacter: hasCharacter,
        onDownload: onDownload ?? () {},
        onUpdate: onUpdate ?? () {},
        onDownloadVoice: onDownloadVoice ?? (_) {},
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
      await tester.pumpWidget(wrap(buildTile(local: localPack, downloadedModelId: 'siwis')));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle), findsWidgets);
    });

    testWidgets('shows delete button on sentences row when downloaded',
        (tester) async {
      await tester.pumpWidget(wrap(buildTile(local: localPack, downloadedModelId: 'siwis')));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.delete_outline), findsWidgets);
    });

    testWidgets('fires onDelete when tapping sentences delete',
        (tester) async {
      var deleted = false;
      await tester.pumpWidget(wrap(buildTile(
        local: localPack,
        downloadedModelId: 'siwis',
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

    testWidgets('shows Extracting subtitle during extraction phase',
        (tester) async {
      await tester.pumpWidget(wrap(buildTile(
        local: localPack,
        downloadedModelId: 'siwis',
        voiceProgress: -1.0,
      )));
      await tester.pump();
      expect(find.textContaining('Extracting'), findsOneWidget);
    });

    // -- Voice row (fra has TTS support) --

    testWidgets('shows voice row for supported languages', (tester) async {
      await tester.pumpWidget(wrap(buildTile()));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    });

    testWidgets('hides voice row for unsupported languages', (tester) async {
      const unsupported = PackInfo(lang: 'zzz', fromLang: 'eng', name: 'Unknown', flag: '?', builtAt: '', schemaVersion: 1);
      await tester.pumpWidget(wrap(buildTile(pack: unsupported, voiceModels: const [])));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
    });

    testWidgets('voice download is disabled when sentences not installed',
        (tester) async {
      String? downloadedId;
      await tester.pumpWidget(wrap(buildTile(
        local: null,
        downloadedModelId: null,
        onDownloadVoice: (id) => downloadedId = id,
      )));
      await tester.pumpAndSettle();

      // Voice download icon should exist but be disabled
      final downloadIcons = find.byIcon(Icons.download_rounded);
      await tester.tap(downloadIcons.last);
      expect(downloadedId, isNull);
    });

    testWidgets('shows voice download button when pack installed but no voice',
        (tester) async {
      String? downloadedId;
      await tester.pumpWidget(wrap(buildTile(
        local: localPack,
        downloadedModelId: null,
        onDownloadVoice: (id) => downloadedId = id,
      )));
      await tester.pumpAndSettle();

      final downloadIcons = find.byIcon(Icons.download_rounded);
      await tester.tap(downloadIcons.last);
      expect(downloadedId, 'siwis');
    });

    testWidgets('fires onDeleteVoice when tapping voice trash', (tester) async {
      var voiceDeleted = false;
      await tester.pumpWidget(wrap(buildTile(
        local: localPack,
        downloadedModelId: 'siwis',
        onDeleteVoice: () => voiceDeleted = true,
      )));
      await tester.pumpAndSettle();

      // Last delete icon is the voice row's
      final deleteIcons = find.byIcon(Icons.delete_outline);
      await tester.tap(deleteIcons.last);
      expect(voiceDeleted, isTrue);
    });

    // -- Voice swap button --

    testWidgets('shows swap button when multiple voices and voice downloaded',
        (tester) async {
      await tester.pumpWidget(wrap(buildTile(
        local: localPack,
        downloadedModelId: 'siwis',
      )));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
    });

    testWidgets('hides swap button when only one voice model', (tester) async {
      await tester.pumpWidget(wrap(buildTile(
        local: localPack,
        downloadedModelId: 'siwis',
        voiceModels: const [
          TtsModelInfo(modelId: 'siwis', displayName: 'Siwis', archiveName: 'vits-piper-fr_FR-siwis-medium', onnxFile: 'fr_FR-siwis-medium.onnx', approximateSizeMB: 61),
        ],
      )));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.swap_horiz), findsNothing);
    });

    testWidgets('hides swap button during voice download', (tester) async {
      await tester.pumpWidget(wrap(buildTile(
        local: localPack,
        downloadedModelId: 'siwis',
        voiceProgress: 0.5,
      )));
      await tester.pump();
      expect(find.byIcon(Icons.swap_horiz), findsNothing);
    });

    testWidgets('shows default voice name before download', (tester) async {
      await tester.pumpWidget(wrap(buildTile()));
      await tester.pumpAndSettle();
      expect(find.text('Siwis'), findsOneWidget);
    });

    testWidgets('shows voice display name as label when downloaded',
        (tester) async {
      await tester.pumpWidget(wrap(buildTile(
        local: localPack,
        downloadedModelId: 'siwis',
      )));
      await tester.pumpAndSettle();
      expect(find.text('Siwis'), findsOneWidget);
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
