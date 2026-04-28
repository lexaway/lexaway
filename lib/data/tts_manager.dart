import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:hive_ce/hive_ce.dart';

import 'content_urls.dart';
import 'download_helper.dart';
import 'hive_keys.dart';

class TtsModelInfo {
  final String modelId;
  final String displayName;
  final String archiveName;
  final String onnxFile;
  final int approximateSizeMB;

  const TtsModelInfo({
    required this.modelId,
    required this.displayName,
    required this.archiveName,
    required this.onnxFile,
    required this.approximateSizeMB,
  });

  static TtsModelInfo? tryFromJson(Map<String, dynamic> json) {
    final modelId = json['model_id'];
    final displayName = json['display_name'];
    final archiveName = json['archive_name'];
    final onnxFile = json['onnx_file'];
    final size = json['approximate_size_mb'];
    if (modelId is! String ||
        displayName is! String ||
        archiveName is! String ||
        onnxFile is! String ||
        size is! int) {
      return null;
    }
    return TtsModelInfo(
      modelId: modelId,
      displayName: displayName,
      archiveName: archiveName,
      onnxFile: onnxFile,
      approximateSizeMB: size,
    );
  }
}

/// Bundled fallback catalog of Piper VITS models, keyed by ISO 639-3 lang code.
///
/// Used at cold start before the remote manifest loads, when the manifest fetch
/// fails with no cache, and as the source for legacy Hive migrations. The
/// runtime catalog merges this with `Manifest.voices` (manifest wins per-lang),
/// so adding new voices to the manifest ships them without an app update.
const kBaselineVoiceCatalog = <String, List<TtsModelInfo>>{
  'eng': [
    TtsModelInfo(modelId: 'hfc_male', displayName: 'HFC Male', archiveName: 'vits-piper-en_US-hfc_male-medium', onnxFile: 'en_US-hfc_male-medium.onnx', approximateSizeMB: 61),
    TtsModelInfo(modelId: 'lessac', displayName: 'Lessac', archiveName: 'vits-piper-en_US-lessac-medium', onnxFile: 'en_US-lessac-medium.onnx', approximateSizeMB: 61),
    TtsModelInfo(modelId: 'amy', displayName: 'Amy', archiveName: 'vits-piper-en_US-amy-low', onnxFile: 'en_US-amy-low.onnx', approximateSizeMB: 16),
    TtsModelInfo(modelId: 'ryan', displayName: 'Ryan', archiveName: 'vits-piper-en_US-ryan-medium', onnxFile: 'en_US-ryan-medium.onnx', approximateSizeMB: 61),
  ],
  'fra': [
    TtsModelInfo(modelId: 'siwis', displayName: 'Siwis', archiveName: 'vits-piper-fr_FR-siwis-medium', onnxFile: 'fr_FR-siwis-medium.onnx', approximateSizeMB: 61),
    TtsModelInfo(modelId: 'tom', displayName: 'Tom', archiveName: 'vits-piper-fr_FR-tom-medium', onnxFile: 'fr_FR-tom-medium.onnx', approximateSizeMB: 61),
    TtsModelInfo(modelId: 'gilles', displayName: 'Gilles', archiveName: 'vits-piper-fr_FR-gilles-low', onnxFile: 'fr_FR-gilles-low.onnx', approximateSizeMB: 16),
    TtsModelInfo(modelId: 'miro', displayName: 'Miro', archiveName: 'vits-piper-fr_FR-miro-high', onnxFile: 'fr_FR-miro-high.onnx', approximateSizeMB: 61),
  ],
  'deu': [
    TtsModelInfo(modelId: 'thorsten', displayName: 'Thorsten', archiveName: 'vits-piper-de_DE-thorsten-medium', onnxFile: 'de_DE-thorsten-medium.onnx', approximateSizeMB: 61),
    TtsModelInfo(modelId: 'eva_k', displayName: 'Eva', archiveName: 'vits-piper-de_DE-eva_k-x_low', onnxFile: 'de_DE-eva_k-x_low.onnx', approximateSizeMB: 16),
    TtsModelInfo(modelId: 'kerstin', displayName: 'Kerstin', archiveName: 'vits-piper-de_DE-kerstin-low', onnxFile: 'de_DE-kerstin-low.onnx', approximateSizeMB: 16),
    TtsModelInfo(modelId: 'thorsten_emotional', displayName: 'Thorsten Emotional', archiveName: 'vits-piper-de_DE-thorsten_emotional-medium', onnxFile: 'de_DE-thorsten_emotional-medium.onnx', approximateSizeMB: 61),
  ],
  'spa': [
    TtsModelInfo(modelId: 'sharvard', displayName: 'Sharvard', archiveName: 'vits-piper-es_ES-sharvard-medium', onnxFile: 'es_ES-sharvard-medium.onnx', approximateSizeMB: 61),
    TtsModelInfo(modelId: 'davefx', displayName: 'Davefx', archiveName: 'vits-piper-es_ES-davefx-medium', onnxFile: 'es_ES-davefx-medium.onnx', approximateSizeMB: 61),
    TtsModelInfo(modelId: 'carlfm', displayName: 'Carlfm', archiveName: 'vits-piper-es_ES-carlfm-x_low', onnxFile: 'es_ES-carlfm-x_low.onnx', approximateSizeMB: 16),
  ],
  'ita': [
    TtsModelInfo(modelId: 'riccardo', displayName: 'Riccardo', archiveName: 'vits-piper-it_IT-riccardo-x_low', onnxFile: 'it_IT-riccardo-x_low.onnx', approximateSizeMB: 16),
    TtsModelInfo(modelId: 'paola', displayName: 'Paola', archiveName: 'vits-piper-it_IT-paola-medium', onnxFile: 'it_IT-paola-medium.onnx', approximateSizeMB: 61),
  ],
  'por': [
    TtsModelInfo(modelId: 'faber', displayName: 'Faber', archiveName: 'vits-piper-pt_BR-faber-medium', onnxFile: 'pt_BR-faber-medium.onnx', approximateSizeMB: 61),
    TtsModelInfo(modelId: 'cadu', displayName: 'Cadu', archiveName: 'vits-piper-pt_BR-cadu-medium', onnxFile: 'pt_BR-cadu-medium.onnx', approximateSizeMB: 61),
    TtsModelInfo(modelId: 'edresson', displayName: 'Edresson', archiveName: 'vits-piper-pt_BR-edresson-low', onnxFile: 'pt_BR-edresson-low.onnx', approximateSizeMB: 16),
  ],
  'nld': [
    TtsModelInfo(modelId: 'pim', displayName: 'Pim', archiveName: 'vits-piper-nl_NL-pim-medium', onnxFile: 'nl_NL-pim-medium.onnx', approximateSizeMB: 61),
    TtsModelInfo(modelId: 'ronnie', displayName: 'Ronnie', archiveName: 'vits-piper-nl_NL-ronnie-medium', onnxFile: 'nl_NL-ronnie-medium.onnx', approximateSizeMB: 61),
    TtsModelInfo(modelId: 'nathalie', displayName: 'Nathalie (BE)', archiveName: 'vits-piper-nl_BE-nathalie-medium', onnxFile: 'nl_BE-nathalie-medium.onnx', approximateSizeMB: 61),
  ],
};

class TtsManager {
  final Box _box;
  final String modelsDir;

  /// Live voice catalog (baseline merged with manifest overrides). Starts at
  /// the bundled baseline so cold-start callers — including TTS playback
  /// before the manifest has loaded — get a working answer. Mutated only via
  /// [setVoiceCatalog]; the Riverpod `voiceCatalogProvider` listener pushes
  /// the merged view in whenever the manifest changes.
  Map<String, List<TtsModelInfo>> _voiceCatalog = kBaselineVoiceCatalog;

  Map<String, List<TtsModelInfo>> get voiceCatalog => _voiceCatalog;

  /// Replace the catalog. Stores an unmodifiable view so accidental mutation
  /// from callers can't leak into the runtime — only the next `setVoiceCatalog`
  /// call rotates the view.
  void setVoiceCatalog(Map<String, List<TtsModelInfo>> next) {
    _voiceCatalog = Map.unmodifiable(next);
  }

  /// Guards against concurrent downloads of the same resource.
  final _activeDownloads = <String, Future<void>>{};

  /// Guards the single shared espeak-ng-data download.
  Completer<void>? _espeakDownload;

  TtsManager(this._box, {required this.modelsDir}) {
    _migrateHiveIfNeeded();
  }

  String get espeakDataPath => '$modelsDir/espeak-ng-data';

  bool get isEspeakDataDownloaded {
    return _box.get(HiveKeys.ttsEspeakNgData, defaultValue: false) as bool;
  }

  Future<void> downloadEspeakData() async {
    if (isEspeakDataDownloaded) return;

    // Serialize concurrent calls — only one download at a time
    if (_espeakDownload != null) {
      return _espeakDownload!.future;
    }
    _espeakDownload = Completer<void>();

    try {
      final dir = modelsDir;
      await Directory(dir).create(recursive: true);

      final tmpPath = '$dir/espeak-ng-data.tar.bz2.tmp';
      final url = await ttsUrl('espeak-ng-data.tar.bz2');
      await downloadToFile(url, tmpPath);
      await _extractInIsolate(tmpPath, dir);
      await File(tmpPath).delete();

      _box.put(HiveKeys.ttsEspeakNgData, true);
      _espeakDownload!.complete();
    } catch (e) {
      _espeakDownload!.completeError(e);
      rethrow;
    } finally {
      _espeakDownload = null;
    }
  }

  bool isModelDownloaded(String lang) {
    return downloadedModelId(lang) != null;
  }

  /// Returns the model_id of the currently downloaded model for [lang],
  /// or null if nothing is downloaded.
  String? downloadedModelId(String lang) {
    final models = _getModels();
    final entry = models[lang];
    if (entry == null) return null;
    return (entry as Map)['model_id'] as String?;
  }

  /// Returns the [TtsModelInfo] for the currently downloaded model for [lang],
  /// or null if nothing is downloaded or the model ID is no longer in the registry.
  TtsModelInfo? downloadedModelInfo(String lang) {
    final id = downloadedModelId(lang);
    if (id == null) return null;
    // Fall back to baseline so a voice that was once shipped — but later
    // dropped from the manifest — still resolves for users who downloaded it.
    final voices = voiceCatalog[lang] ?? kBaselineVoiceCatalog[lang];
    if (voices == null) return null;
    for (final m in voices) {
      if (m.modelId == id) return m;
    }
    return null;
  }

  /// Returns the directory containing the model files for [lang],
  /// or null if not downloaded.
  String? modelDir(String lang) {
    final models = _getModels();
    final entry = models[lang];
    if (entry == null) return null;
    final archiveName = (entry as Map)['archive_name'] as String?;
    if (archiveName == null) return null;
    return '$modelsDir/$archiveName';
  }

  Future<void> downloadModel(
    String lang, {
    String? modelId,
    void Function(double)? onProgress,
    void Function()? onExtracting,
  }) async {
    final voices = voiceCatalog[lang];
    if (voices == null || voices.isEmpty) return;

    final info = modelId != null
        ? voices.firstWhere((m) => m.modelId == modelId, orElse: () => voices.first)
        : voices.first;

    // If the same model is already downloaded, nothing to do
    if (downloadedModelId(lang) == info.modelId) return;

    // Reject if a download for this lang is already in flight
    if (_activeDownloads.containsKey(lang)) return;

    final future = _doDownloadModel(lang, info, onProgress: onProgress, onExtracting: onExtracting);
    _activeDownloads[lang] = future;
    try {
      await future;
    } finally {
      _activeDownloads.remove(lang);
    }
  }

  Future<void> _doDownloadModel(
    String lang,
    TtsModelInfo info, {
    void Function(double)? onProgress,
    void Function()? onExtracting,
  }) async {
    // Ensure espeak-ng-data is present first
    await downloadEspeakData();

    final dir = modelsDir;
    await Directory(dir).create(recursive: true);

    // Download the new model first, then swap — so if the download fails
    // the old model is still intact.
    final tmpPath = '$dir/${info.archiveName}.tar.bz2.tmp';
    try {
      final url = await ttsUrl('${info.archiveName}.tar.bz2');
      await downloadToFile(url, tmpPath, onProgress: onProgress);
      onExtracting?.call();
      await _extractInIsolate(tmpPath, dir);
      await File(tmpPath).delete();
    } catch (_) {
      // Clean up partial extraction
      final partial = Directory('$dir/${info.archiveName}');
      if (await partial.exists()) await partial.delete(recursive: true);
      final tmp = File(tmpPath);
      if (await tmp.exists()) await tmp.delete();
      rethrow;
    }

    // New model is fully extracted — now remove the old one if present
    final models = _getModels();
    final oldEntry = models[lang];
    if (oldEntry != null) {
      final oldArchive = (oldEntry as Map)['archive_name'] as String?;
      if (oldArchive != null && oldArchive != info.archiveName) {
        final oldDir = Directory('$dir/$oldArchive');
        if (await oldDir.exists()) await oldDir.delete(recursive: true);
      }
    }

    models[lang] = {
      'archive_name': info.archiveName,
      'model_id': info.modelId,
      'downloaded_at': DateTime.now().toUtc().toIso8601String(),
    };
    _box.put(HiveKeys.ttsModels, models);
  }

  Future<void> deleteModel(String lang) async {
    final models = _getModels();
    final entry = models[lang];
    if (entry == null) return;

    final archiveName = (entry as Map)['archive_name'] as String?;
    if (archiveName != null) {
      final modelDirectory = Directory('$modelsDir/$archiveName');
      if (await modelDirectory.exists()) {
        await modelDirectory.delete(recursive: true);
      }
    }

    models.remove(lang);
    _box.put(HiveKeys.ttsModels, models);
  }

  /// Whether TTS is supported at all for this language. Reflects the live
  /// catalog (baseline + manifest overrides), so a manifest-only language
  /// becomes supported once the manifest has loaded.
  bool isSupported(String lang) {
    final voices = voiceCatalog[lang];
    return voices != null && voices.isNotEmpty;
  }

  /// Backfill model_id for downloads made before multi-voice support.
  void _migrateHiveIfNeeded() {
    final models = _getModels();
    var dirty = false;
    final migrated = <String, dynamic>{};
    for (final entry in models.entries) {
      final data = Map<String, dynamic>.from(entry.value as Map);
      if (!data.containsKey('model_id')) {
        final archiveName = data['archive_name'] as String?;
        final voices = kBaselineVoiceCatalog[entry.key];
        if (archiveName != null && voices != null) {
          for (final m in voices) {
            if (m.archiveName == archiveName) {
              data['model_id'] = m.modelId;
              dirty = true;
              break;
            }
          }
        }
      }
      migrated[entry.key] = data;
    }
    if (dirty) _box.put(HiveKeys.ttsModels, migrated);
  }

  Map<String, dynamic> _getModels() {
    final raw = _box.get(HiveKeys.ttsModels);
    if (raw == null) return {};
    return Map<String, dynamic>.from(raw as Map);
  }

  /// Decompress + extract tar.bz2 in a background isolate to avoid
  /// blocking the UI and to keep peak memory off the main isolate.
  static Future<void> _extractInIsolate(
    String archivePath,
    String destinationDir,
  ) {
    return Isolate.run(() {
      final bytes = File(archivePath).readAsBytesSync();
      final decompressed = BZip2Decoder().decodeBytes(bytes);
      final archive = TarDecoder().decodeBytes(decompressed);

      for (final file in archive) {
        final path = '$destinationDir/${file.name}';
        if (file.isFile) {
          final outFile = File(path);
          outFile.createSync(recursive: true);
          outFile.writeAsBytesSync(file.content as List<int>);
        } else {
          Directory(path).createSync(recursive: true);
        }
      }
    });
  }
}
