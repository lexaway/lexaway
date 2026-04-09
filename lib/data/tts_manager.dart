import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:hive_ce/hive_ce.dart';

import 'content_urls.dart';
import 'download_helper.dart';
import 'hive_keys.dart';

class TtsModelInfo {
  final String archiveName;
  final String onnxFile;
  final int approximateSizeMB;

  const TtsModelInfo({
    required this.archiveName,
    required this.onnxFile,
    required this.approximateSizeMB,
  });

}

/// Registry of Piper VITS models, keyed by ISO 639-3 language code
/// (matching the pack manifest).
const ttsModelRegistry = <String, TtsModelInfo>{
  'fra': TtsModelInfo(
    archiveName: 'vits-piper-fr_FR-siwis-medium',
    onnxFile: 'fr_FR-siwis-medium.onnx',
    approximateSizeMB: 61,
  ),
  'deu': TtsModelInfo(
    archiveName: 'vits-piper-de_DE-thorsten-medium',
    onnxFile: 'de_DE-thorsten-medium.onnx',
    approximateSizeMB: 61,
  ),
  'spa': TtsModelInfo(
    archiveName: 'vits-piper-es_ES-davefx-medium',
    onnxFile: 'es_ES-davefx-medium.onnx',
    approximateSizeMB: 61,
  ),
  'ita': TtsModelInfo(
    archiveName: 'vits-piper-it_IT-riccardo-x_low',
    onnxFile: 'it_IT-riccardo-x_low.onnx',
    approximateSizeMB: 16,
  ),
  'por': TtsModelInfo(
    archiveName: 'vits-piper-pt_BR-faber-medium',
    onnxFile: 'pt_BR-faber-medium.onnx',
    approximateSizeMB: 61,
  ),
  'jpn': TtsModelInfo(
    archiveName: 'vits-piper-ja_JP-amitaro-medium',
    onnxFile: 'ja_JP-amitaro-medium.onnx',
    approximateSizeMB: 61,
  ),
};

class TtsManager {
  final Box _box;
  final String modelsDir;

  /// Guards against concurrent downloads of the same resource.
  final _activeDownloads = <String, Future<void>>{};

  /// Guards the single shared espeak-ng-data download.
  Completer<void>? _espeakDownload;

  TtsManager(this._box, {required this.modelsDir});

  // -- espeak-ng-data (shared by all Piper models) --

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

  // -- Model download/delete --

  bool isModelDownloaded(String lang) {
    final models = _getModels();
    return models.containsKey(lang);
  }

  /// Returns the directory containing the model files for [lang],
  /// or null if not downloaded.
  String? modelDir(String lang) {
    if (!isModelDownloaded(lang)) return null;
    final info = ttsModelRegistry[lang];
    if (info == null) return null;
    return '$modelsDir/${info.archiveName}';
  }

  Future<void> downloadModel(
    String lang, {
    void Function(double)? onProgress,
  }) async {
    final info = ttsModelRegistry[lang];
    if (info == null) return;
    if (isModelDownloaded(lang)) return;

    // Prevent double-tap: if already downloading this lang, join the existing future
    if (_activeDownloads.containsKey(lang)) {
      return _activeDownloads[lang];
    }

    final future = _doDownloadModel(lang, info, onProgress: onProgress);
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
  }) async {
    // Ensure espeak-ng-data is present first
    await downloadEspeakData();

    final dir = modelsDir;
    await Directory(dir).create(recursive: true);

    final tmpPath = '$dir/${info.archiveName}.tar.bz2.tmp';
    try {
      final url = await ttsUrl('${info.archiveName}.tar.bz2');
      await downloadToFile(url, tmpPath, onProgress: onProgress);
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

    final models = _getModels();
    models[lang] = {
      'archive_name': info.archiveName,
      'downloaded_at': DateTime.now().toUtc().toIso8601String(),
    };
    _box.put(HiveKeys.ttsModels, models);
  }

  Future<void> deleteModel(String lang) async {
    final info = ttsModelRegistry[lang];
    if (info == null) return;

    final dir = modelsDir;
    final modelDirectory = Directory('$dir/${info.archiveName}');
    if (await modelDirectory.exists()) {
      await modelDirectory.delete(recursive: true);
    }

    final models = _getModels();
    models.remove(lang);
    _box.put(HiveKeys.ttsModels, models);
  }

  /// Whether TTS is supported at all for this language.
  static bool isSupported(String lang) => ttsModelRegistry.containsKey(lang);

  // -- Internals --

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
