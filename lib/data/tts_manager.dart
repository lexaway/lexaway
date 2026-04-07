import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:path_provider/path_provider.dart';

import 'download_helper.dart';

const _modelsBaseUrl =
    'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models';

class TtsModelInfo {
  final String archiveName;
  final String onnxFile;
  final int approximateSizeMB;

  const TtsModelInfo({
    required this.archiveName,
    required this.onnxFile,
    required this.approximateSizeMB,
  });

  String get downloadUrl => '$_modelsBaseUrl/$archiveName.tar.bz2';
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
  String? _cachedModelsDir;

  /// Guards against concurrent downloads of the same resource.
  final _activeDownloads = <String, Future<void>>{};

  /// Guards the single shared espeak-ng-data download.
  Completer<void>? _espeakDownload;

  TtsManager(this._box);

  Future<String> get _modelsDir async {
    if (_cachedModelsDir != null) return _cachedModelsDir!;
    final dir = await getApplicationSupportDirectory();
    _cachedModelsDir = '${dir.path}/tts_models';
    return _cachedModelsDir!;
  }

  // -- espeak-ng-data (shared by all Piper models) --

  Future<String> get espeakDataPath async {
    final dir = await _modelsDir;
    return '$dir/espeak-ng-data';
  }

  bool get isEspeakDataDownloaded {
    return _box.get('tts_espeak_ng_data', defaultValue: false) as bool;
  }

  Future<void> downloadEspeakData() async {
    if (isEspeakDataDownloaded) return;

    // Serialize concurrent calls — only one download at a time
    if (_espeakDownload != null) {
      return _espeakDownload!.future;
    }
    _espeakDownload = Completer<void>();

    try {
      final dir = await _modelsDir;
      await Directory(dir).create(recursive: true);

      final tmpPath = '$dir/espeak-ng-data.tar.bz2.tmp';
      await downloadToFile('$_modelsBaseUrl/espeak-ng-data.tar.bz2', tmpPath);
      await _extractInIsolate(tmpPath, dir);
      await File(tmpPath).delete();

      _box.put('tts_espeak_ng_data', true);
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
  Future<String?> modelDir(String lang) async {
    if (!isModelDownloaded(lang)) return null;
    final info = ttsModelRegistry[lang];
    if (info == null) return null;
    final dir = await _modelsDir;
    return '$dir/${info.archiveName}';
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

    final dir = await _modelsDir;
    await Directory(dir).create(recursive: true);

    final tmpPath = '$dir/${info.archiveName}.tar.bz2.tmp';
    try {
      await downloadToFile(info.downloadUrl, tmpPath, onProgress: onProgress);
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
    _box.put('tts_models', models);
  }

  Future<void> deleteModel(String lang) async {
    final info = ttsModelRegistry[lang];
    if (info == null) return;

    final dir = await _modelsDir;
    final modelDirectory = Directory('$dir/${info.archiveName}');
    if (await modelDirectory.exists()) {
      await modelDirectory.delete(recursive: true);
    }

    final models = _getModels();
    models.remove(lang);
    _box.put('tts_models', models);
  }

  /// Whether TTS is supported at all for this language.
  static bool isSupported(String lang) => ttsModelRegistry.containsKey(lang);

  // -- Internals --

  Map<String, dynamic> _getModels() {
    final raw = _box.get('tts_models');
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
