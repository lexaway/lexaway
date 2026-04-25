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

/// Probes each base URL with a HEAD request. Returns the first that responds
/// with a non-error status. Falls through on definitive failures (HTTP 5xx,
/// DNS resolution errors); on timeout, sticks with the URL being probed
/// since a slow primary is still more likely to work than a non-existent
/// fallback. If every URL fails definitively, returns the last as a final
/// fallback so callers always get *something* to attempt.
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
