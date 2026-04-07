import 'dart:io';

import 'package:http/http.dart' as http;

/// Stream an HTTP response directly to a file on disk, with optional
/// progress reporting (0.0 → 1.0).
///
/// On failure the partial file is deleted before rethrowing.
Future<void> downloadToFile(
  String url,
  String destPath, {
  void Function(double)? onProgress,
}) async {
  final request = http.Request('GET', Uri.parse(url))
    ..followRedirects = true
    ..maxRedirects = 5;
  final client = http.Client();
  try {
    final response = await client.send(request);

    if (response.statusCode != 200) {
      throw Exception('Download failed: HTTP ${response.statusCode}');
    }

    final totalBytes = response.contentLength ?? 0;
    final outFile = File(destPath);
    final sink = outFile.openWrite();

    int received = 0;
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (totalBytes > 0 && onProgress != null) {
          onProgress(received / totalBytes);
        }
      }
      await sink.close();
    } catch (_) {
      await sink.close();
      if (await outFile.exists()) await outFile.delete();
      rethrow;
    }
  } finally {
    client.close();
  }
}
