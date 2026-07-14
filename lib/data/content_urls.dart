import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const _packsUrls = [
  'https://github.com/lexaway/lexaway-packs/releases/latest/download',
  'https://lexaway.com/packs',
];

const _ttsUrls = [
  'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models',
  'https://lexaway.com/tts-models',
];

String? _resolvedPacksBase;
String? _resolvedTtsBase;

/// Resolves the first reachable base URL for language packs, then appends
/// [path]. The resolved base is cached for the session.
Future<String> packsUrl(String path) async {
  _resolvedPacksBase ??= await _probe(_packsUrls);
  return '$_resolvedPacksBase/$path';
}

/// Resolves the first reachable base URL for TTS models, then appends [path].
/// The resolved base is cached for the session.
Future<String> ttsUrl(String path) async {
  _resolvedTtsBase ??= await _probe(_ttsUrls);
  return '$_resolvedTtsBase/$path';
}

/// HEAD-probes each base URL, returning the first with a non-error status.
/// Definitive failures (5xx, DNS) fall through to the next; a timeout sticks
/// with the current URL (a slow primary beats a non-existent fallback). If all
/// fail definitively, returns the last so callers always have something to try.
Future<String> _probe(List<String> baseUrls) async {
  for (var i = 0; i < baseUrls.length; i++) {
    try {
      final response = await http.head(Uri.parse(baseUrls[i])).timeout(
        const Duration(seconds: 5),
      );
      if (response.statusCode < 500) return baseUrls[i];
      debugPrint('content_urls: ${baseUrls[i]} returned ${response.statusCode}, trying fallback');
    } on SocketException catch (e) {
      // DNS or connection refused — definitive failure, try next
      debugPrint('content_urls: ${baseUrls[i]} unreachable ($e), trying fallback');
    } catch (_) {
      // Timeout or other transient error — stick with this URL.
      return baseUrls[i];
    }
  }
  return baseUrls.last;
}
