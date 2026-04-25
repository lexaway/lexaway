import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'tts_manager.dart';

/// Resolved model paths sent to the background isolate.
class _ModelPaths {
  final String modelPath;
  final String tokensPath;
  final String espeakDataPath;
  final String lang;
  final String modelId;

  const _ModelPaths({
    required this.modelPath,
    required this.tokensPath,
    required this.espeakDataPath,
    required this.lang,
    required this.modelId,
  });
}

/// Request sent from main isolate → background isolate.
class _GenerateRequest {
  final int id;
  final String text;
  final _ModelPaths? paths;

  const _GenerateRequest({required this.id, required this.text, this.paths});
}

/// Sentinel request telling the isolate to free native resources and exit.
class _ShutdownRequest {
  const _ShutdownRequest();
}

/// Response sent from background isolate → main isolate.
class _GenerateResponse {
  final int id;
  final Uint8List? wavBytes;

  const _GenerateResponse({required this.id, this.wavBytes});
}

class TtsService {
  final String tmpDir;
  final _player = AudioPlayer();

  TtsService({required this.tmpDir});

  int _playbackId = 0;
  bool _speaking = false;
  bool get isSpeaking => _speaking;

  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;
  Future<void>? _initFuture;
  final _pendingRequests = <int, Completer<Uint8List?>>{};
  int _requestId = 0;

  /// Ensure the background isolate is running and ready.
  /// Guarded so concurrent callers share the same spawn.
  Future<void> _ensureIsolate() {
    if (_sendPort != null) return Future.value();
    return _initFuture ??= _spawnIsolate();
  }

  Future<void> _spawnIsolate() async {
    final receivePort = ReceivePort();
    _receivePort = receivePort;

    _isolate = await Isolate.spawn(
      _isolateEntryPoint,
      receivePort.sendPort,
    );

    // Drain pending requests if the isolate dies unexpectedly.
    _isolate!.addOnExitListener(receivePort.sendPort);

    final initCompleter = Completer<SendPort>();
    receivePort.listen((message) {
      if (message is SendPort) {
        initCompleter.complete(message);
      } else if (message is _GenerateResponse) {
        final completer = _pendingRequests.remove(message.id);
        completer?.complete(message.wavBytes);
      } else if (message == null) {
        // Isolate exited — complete all pending requests with null.
        _onIsolateDied();
      }
    });

    _sendPort = await initCompleter.future;
  }

  void _onIsolateDied() {
    _isolate = null;
    _sendPort = null;
    _initFuture = null;
    _receivePort?.close();
    _receivePort = null;
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) completer.complete(null);
    }
    _pendingRequests.clear();
  }

  /// Resolve model paths from TtsManager on the main isolate.
  _ModelPaths? _resolvePaths(String lang, TtsManager ttsManager) {
    final info = ttsManager.downloadedModelInfo(lang);
    if (info == null) return null;
    final dir = ttsManager.modelDir(lang);
    if (dir == null) return null;

    final modelPath = '$dir/${info.onnxFile}';
    if (!File(modelPath).existsSync()) return null;

    return _ModelPaths(
      modelPath: modelPath,
      tokensPath: '$dir/tokens.txt',
      espeakDataPath: ttsManager.espeakDataPath,
      lang: lang,
      modelId: info.modelId,
    );
  }

  /// Generate WAV audio for [text] and return it as bytes.
  /// Runs on a background isolate — does not block the UI thread.
  Future<Uint8List?> generateWavBytes(
    String text, {
    required String lang,
    required TtsManager ttsManager,
  }) async {
    await _ensureIsolate();
    if (_sendPort == null) return null; // isolate died during init

    // Always send paths — let the isolate decide whether to re-init.
    // This avoids main/isolate tracking getting out of sync if engine
    // init fails on the isolate side.
    final paths = _resolvePaths(lang, ttsManager);
    if (paths == null) return null;

    final id = ++_requestId;
    final completer = Completer<Uint8List?>();
    _pendingRequests[id] = completer;

    _sendPort!.send(_GenerateRequest(id: id, text: text, paths: paths));

    return completer.future;
  }

  /// Play pre-generated WAV bytes. Cancels any current playback.
  ///
  /// Writes to a temp .wav file rather than using BytesSource because
  /// AVPlayer on iOS can't determine the format from extensionless cache files.
  Future<void> playBytes(Uint8List wavBytes, {double volume = 1.0}) async {
    final myId = ++_playbackId;

    if (_speaking) {
      await _stopPlayback();
    }

    _speaking = true;
    try {
      final wavPath = '$tmpDir/tts_${myId % 2}.wav';
      await File(wavPath).writeAsBytes(wavBytes, flush: true);

      if (myId != _playbackId) return;

      final completer = Completer<void>();
      final sub = _player.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });

      try {
        await _player.setVolume(volume.clamp(0.0, 1.0));
        await _player.play(DeviceFileSource(wavPath));
        await completer.future;
      } finally {
        await sub.cancel();
      }
    } catch (_) {
      // Swallow errors — speaker should silently fail rather than crash.
    } finally {
      if (myId == _playbackId) {
        _speaking = false;
      }
    }
  }

  /// Speak [text] in the given [lang]. Lazily initialises the TTS engine
  /// for that language if needed.
  Future<void> speak(
    String text, {
    required String lang,
    required TtsManager ttsManager,
    double volume = 1.0,
  }) async {
    final bytes = await generateWavBytes(text, lang: lang, ttsManager: ttsManager);
    if (bytes == null) return;
    await playBytes(bytes, volume: volume);
  }

  Future<void> stop() async {
    _playbackId++;
    await _stopPlayback();
  }

  Future<void> _stopPlayback() async {
    await _player.stop();
    _speaking = false;
  }

  /// Release the native TTS engine. Call before deleting model files.
  /// Sends a graceful shutdown so the isolate can free native resources.
  void releaseEngine() {
    if (_sendPort != null) {
      _sendPort!.send(const _ShutdownRequest());
    }
    // The isolate will call Isolate.exit(), triggering _onIsolateDied
    // via the exit listener. But also clean up immediately on our side
    // so callers don't send to a dying isolate.
    _onIsolateDied();
  }

  void dispose() {
    _player.dispose();
    releaseEngine();
  }
}

/// Entry point for the long-lived TTS generation isolate.
void _isolateEntryPoint(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  bool bindingsInitialized = false;
  sherpa.OfflineTts? tts;
  String? currentLang;
  String? currentModelId;

  receivePort.listen((message) {
    if (message is _ShutdownRequest) {
      tts?.free();
      tts = null;
      receivePort.close();
      Isolate.exit();
    }

    if (message is! _GenerateRequest) return;

    final request = message;

    // Re-init engine if language/model changed
    if (request.paths != null) {
      final paths = request.paths!;

      if (currentLang != paths.lang || currentModelId != paths.modelId) {
        tts?.free();
        tts = null;

        if (!bindingsInitialized) {
          sherpa.initBindings();
          bindingsInitialized = true;
        }

        try {
          final vitsConfig = sherpa.OfflineTtsVitsModelConfig(
            model: paths.modelPath,
            lexicon: '',
            tokens: paths.tokensPath,
            dataDir: paths.espeakDataPath,
          );

          final modelConfig = sherpa.OfflineTtsModelConfig(
            vits: vitsConfig,
            numThreads: 2,
            debug: false,
          );

          final config = sherpa.OfflineTtsConfig(model: modelConfig);

          tts = sherpa.OfflineTts(config);
          currentLang = paths.lang;
          currentModelId = paths.modelId;
        } catch (_) {
          tts = null;
          currentLang = null;
          currentModelId = null;
        }
      }
    }

    if (tts == null) {
      mainSendPort.send(_GenerateResponse(id: request.id));
      return;
    }

    try {
      final audio = tts!.generate(text: request.text, sid: 0, speed: 1.0);
      if (audio.samples.isEmpty) {
        mainSendPort.send(_GenerateResponse(id: request.id));
        return;
      }

      final wavBytes = _encodeWav(audio.samples, audio.sampleRate);
      mainSendPort.send(_GenerateResponse(id: request.id, wavBytes: wavBytes));
    } catch (_) {
      mainSendPort.send(_GenerateResponse(id: request.id));
    }
  });
}

/// Encode PCM float samples as a WAV byte buffer.
Uint8List _encodeWav(Float32List samples, int sampleRate) {
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

  // Peak-normalize so quiet models use the full 16-bit range.
  var peak = 0.0;
  for (var i = 0; i < numSamples; i++) {
    final abs = samples[i].abs();
    if (abs > peak) peak = abs;
  }
  final gain = (peak > 0.0 && peak < 1.0) ? 1.0 / peak : 1.0;

  // Convert float samples to 16-bit PCM
  for (var i = 0; i < numSamples; i++) {
    final scaled = (samples[i] * gain).clamp(-1.0, 1.0);
    final pcm = (scaled * 32767).round().clamp(-32768, 32767);
    buffer.setInt16(44 + i * 2, pcm, Endian.little);
  }

  return buffer.buffer.asUint8List();
}
