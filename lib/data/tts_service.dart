import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'tts_manager.dart';

class TtsService {
  static bool _bindingsInitialized = false;

  final String tmpDir;
  sherpa.OfflineTts? _tts;
  String? _currentLang;
  String? _currentModelId;
  final _player = AudioPlayer();

  TtsService({required this.tmpDir});

  /// Monotonically increasing ID — each speak() call gets a unique one.
  /// If a newer call arrives, older ones are discarded.
  int _generationId = 0;

  bool _speaking = false;
  bool get isSpeaking => _speaking;

  /// Speak [text] in the given [lang]. Lazily initialises the TTS engine
  /// for that language if needed.
  Future<void> speak(
    String text, {
    required String lang,
    required TtsManager ttsManager,
    double volume = 1.0,
  }) async {
    // Bump generation ID — any in-flight work for older IDs will be discarded
    final myId = ++_generationId;

    if (_speaking) {
      await stop();
    }

    // Re-init engine if language or model changed
    final activeModelId = ttsManager.downloadedModelId(lang);
    if (_currentLang != lang || _currentModelId != activeModelId || _tts == null) {
      _releaseEngine();
      await _init(lang, ttsManager);
    }

    if (_tts == null) return;
    if (myId != _generationId) return; // superseded while initializing

    _speaking = true;
    try {
      // Generate audio synchronously via FFI — this is fast enough for short
      // sentences on modern devices (~200-500ms). If profiling shows jank,
      // this can be moved to an isolate, but OfflineTts holds a native pointer
      // that can't cross isolate boundaries, so it would need full init per call.
      final audio = _tts!.generate(text: text, sid: 0, speed: 1.0);
      if (audio.samples.isEmpty) return;
      if (myId != _generationId) return; // superseded during generation

      // Unique filename per generation to avoid WAV file races
      final wavPath = '$tmpDir/tts_${myId % 2}.wav';
      _writeWav(wavPath, audio.samples, audio.sampleRate);

      if (myId != _generationId) return; // superseded during file write

      // Subscribe to completion BEFORE calling play to avoid missing the event
      final completer = Completer<void>();
      final sub = _player.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });

      try {
        await _player.setVolume(volume.clamp(0.0, 1.0));
      await _player.play(DeviceFileSource(wavPath));
        // Wait for playback, but also complete if stop() is called
        await completer.future;
      } finally {
        await sub.cancel();
      }
    } catch (_) {
      // Swallow errors (corrupt model, disk full, etc.) — the speaker icon
      // should just silently fail rather than crashing the game.
    } finally {
      if (myId == _generationId) {
        _speaking = false;
      }
    }
  }

  Future<void> stop() async {
    _generationId++; // invalidate any in-flight work
    await _player.stop();
    _speaking = false;
  }

  /// Release the native TTS engine. Call before deleting model files.
  void releaseEngine() => _releaseEngine();

  void dispose() {
    _player.dispose();
    _releaseEngine();
  }

  // -- Internals --

  Future<void> _init(String lang, TtsManager ttsManager) async {
    final info = ttsManager.downloadedModelInfo(lang);
    if (info == null) return;

    final dir = ttsManager.modelDir(lang);
    if (dir == null) return;

    final espeakDir = ttsManager.espeakDataPath;
    final modelPath = '$dir/${info.onnxFile}';
    final tokensPath = '$dir/tokens.txt';

    if (!_bindingsInitialized) {
      sherpa.initBindings();
      _bindingsInitialized = true;
    }

    if (!File(modelPath).existsSync()) return;

    try {
      final vitsConfig = sherpa.OfflineTtsVitsModelConfig(
        model: modelPath,
        lexicon: '',
        tokens: tokensPath,
        dataDir: espeakDir,
      );

      final modelConfig = sherpa.OfflineTtsModelConfig(
        vits: vitsConfig,
        numThreads: 2,
        debug: false,
      );

      final config = sherpa.OfflineTtsConfig(model: modelConfig);

      _tts = sherpa.OfflineTts(config);
      _currentLang = lang;
      _currentModelId = info.modelId;
    } catch (_) {
      // Model files may be corrupt — fail gracefully
      _tts = null;
      _currentLang = null;
      _currentModelId = null;
    }
  }

  void _releaseEngine() {
    _tts?.free();
    _tts = null;
    _currentLang = null;
    _currentModelId = null;
  }

  /// Write PCM float samples to a WAV file.
  void _writeWav(String path, Float32List samples, int sampleRate) {
    final numSamples = samples.length;
    final byteRate = sampleRate * 2; // 16-bit mono
    final dataSize = numSamples * 2;
    final fileSize = 36 + dataSize;

    final buffer = ByteData(44 + dataSize);
    // RIFF header
    buffer.setUint8(0, 0x52); // R
    buffer.setUint8(1, 0x49); // I
    buffer.setUint8(2, 0x46); // F
    buffer.setUint8(3, 0x46); // F
    buffer.setUint32(4, fileSize, Endian.little);
    buffer.setUint8(8, 0x57); // W
    buffer.setUint8(9, 0x41); // A
    buffer.setUint8(10, 0x56); // V
    buffer.setUint8(11, 0x45); // E
    // fmt chunk
    buffer.setUint8(12, 0x66); // f
    buffer.setUint8(13, 0x6D); // m
    buffer.setUint8(14, 0x74); // t
    buffer.setUint8(15, 0x20); // (space)
    buffer.setUint32(16, 16, Endian.little); // chunk size
    buffer.setUint16(20, 1, Endian.little); // PCM format
    buffer.setUint16(22, 1, Endian.little); // mono
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, byteRate, Endian.little);
    buffer.setUint16(32, 2, Endian.little); // block align
    buffer.setUint16(34, 16, Endian.little); // bits per sample
    // data chunk
    buffer.setUint8(36, 0x64); // d
    buffer.setUint8(37, 0x61); // a
    buffer.setUint8(38, 0x74); // t
    buffer.setUint8(39, 0x61); // a
    buffer.setUint32(40, dataSize, Endian.little);

    // Convert float samples to 16-bit PCM
    for (var i = 0; i < numSamples; i++) {
      final clamped = samples[i].clamp(-1.0, 1.0);
      final pcm = (clamped * 32767).round().clamp(-32768, 32767);
      buffer.setInt16(44 + i * 2, pcm, Endian.little);
    }

    File(path).writeAsBytesSync(buffer.buffer.asUint8List());
  }
}
