import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'tts_manager.dart';
import 'tts_service.dart';

/// In-memory cache of generated TTS audio with a background prefetch queue.
class TtsCache {
  final TtsService ttsService;
  final TtsManager ttsManager;
  final int maxEntries;

  TtsCache({
    required this.ttsService,
    required this.ttsManager,
    this.maxEntries = 60,
  });

  final _cache = <String, Uint8List>{};
  final _inFlight = <String, Future<Uint8List?>>{};
  final _queue = Queue<_PrefetchEntry>();
  bool _processing = false;
  int _batchId = 0;

  String _key(String lang, String text) => '$lang:${text.trim().toLowerCase()}';

  /// Return cached audio or null.
  Uint8List? get(String lang, String text) => _cache[_key(lang, text)];

  /// Return cached audio, await in-flight generation, or generate on demand.
  Future<Uint8List?> getOrGenerate(String lang, String text) {
    final key = _key(lang, text);

    final cached = _cache[key];
    if (cached != null) return Future.value(cached);

    final pending = _inFlight[key];
    if (pending != null) return pending;

    return _generate(lang, text, key);
  }

  /// Enqueue texts for background prefetch. Cancels any stale queue entries
  /// from a previous question.
  void prefetch(String lang, List<String> texts) {
    _batchId++;
    _queue.clear();
    final batch = _batchId;
    for (final text in texts) {
      final key = _key(lang, text);
      if (_cache.containsKey(key) || _inFlight.containsKey(key)) continue;
      _queue.add(_PrefetchEntry(lang: lang, text: text, key: key, batchId: batch));
    }
    if (!_processing) _processQueue();
  }

  Future<void> _processQueue() async {
    _processing = true;
    while (_queue.isNotEmpty) {
      final entry = _queue.removeFirst();
      if (entry.batchId != _batchId) continue;
      if (_cache.containsKey(entry.key)) continue;

      await _generate(entry.lang, entry.text, entry.key);
    }
    _processing = false;
  }

  /// Single owner of _inFlight bookkeeping. All generation goes through here.
  Future<Uint8List?> _generate(String lang, String text, String key) {
    final future = ttsService
        .generateWavBytes(text, lang: lang, ttsManager: ttsManager)
        .then((bytes) {
      if (bytes != null) {
        _cache[key] = bytes;
        _evict();
      }
      return bytes;
    }).whenComplete(() {
      _inFlight.remove(key);
    });
    _inFlight[key] = future;
    return future;
  }

  void _evict() {
    while (_cache.length > maxEntries) {
      _cache.remove(_cache.keys.first);
    }
  }
}

class _PrefetchEntry {
  final String lang;
  final String text;
  final String key;
  final int batchId;

  const _PrefetchEntry({
    required this.lang,
    required this.text,
    required this.key,
    required this.batchId,
  });
}
