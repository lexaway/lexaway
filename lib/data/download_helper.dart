import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
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

/// Decompress + extract a tar.bz2 archive in a background isolate so the UI
/// doesn't hitch on bzip2 decode and peak memory stays off the main isolate.
Future<void> extractTarBz2InIsolate(
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
