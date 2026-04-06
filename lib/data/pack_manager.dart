import 'dart:convert';
import 'dart:io';

import 'package:hive_ce/hive_ce.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

const _baseUrl =
    'https://github.com/lexaway/lexaway-packs/releases/latest/download';

class PackInfo {
  final String lang;
  final String name;
  final String flag;

  const PackInfo({required this.lang, required this.name, required this.flag});

  factory PackInfo.fromJson(Map<String, dynamic> json) => PackInfo(
        lang: json['lang'] as String,
        name: json['name'] as String,
        flag: json['flag'] as String,
      );
}

class LocalPack {
  final String lang;
  final int schemaVersion;
  final String builtAt;
  final int sizeBytes;

  const LocalPack({
    required this.lang,
    required this.schemaVersion,
    required this.builtAt,
    required this.sizeBytes,
  });

  factory LocalPack.fromJson(String lang, Map<String, dynamic> json) =>
      LocalPack(
        lang: lang,
        schemaVersion: json['schema_version'] as int,
        builtAt: json['built_at'] as String,
        sizeBytes: json['size_bytes'] as int,
      );

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'built_at': builtAt,
        'size_bytes': sizeBytes,
      };
}

class Manifest {
  final int schemaVersion;
  final List<PackInfo> packs;

  const Manifest({required this.schemaVersion, required this.packs});

  factory Manifest.fromJson(Map<String, dynamic> json) => Manifest(
        schemaVersion: json['schema_version'] as int,
        packs: (json['packs'] as List)
            .map((p) => PackInfo.fromJson(p as Map<String, dynamic>))
            .toList(),
      );
}

class PackManager {
  final Box _box;

  PackManager(this._box);

  Future<String> get _packsDir async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/packs';
  }

  // -- Manifest --

  Future<Manifest> fetchManifest() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/manifest.json'));
      if (response.statusCode == 200) {
        _box.put('manifest_cache', response.body);
        return Manifest.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
      }
    } catch (_) {
      // Fall through to cached version
    }

    final cached = _box.get('manifest_cache') as String?;
    if (cached != null) {
      return Manifest.fromJson(jsonDecode(cached) as Map<String, dynamic>);
    }

    throw Exception('No manifest available (network failed, no cache)');
  }

  // -- Download --

  Future<void> downloadPack(
    String lang, {
    void Function(double)? onProgress,
  }) async {
    final dir = await _packsDir;
    await Directory(dir).create(recursive: true);

    final request = http.Request('GET', Uri.parse('$_baseUrl/$lang.db'))
      ..followRedirects = true
      ..maxRedirects = 5;
    final client = http.Client();
    try {
      final streamed = await client.send(request);

      if (streamed.statusCode != 200) {
        throw Exception('Download failed: HTTP ${streamed.statusCode}');
      }

      final totalBytes = streamed.contentLength ?? 0;
      final tmpPath = '$dir/$lang.db.tmp';
      final outFile = File(tmpPath);
      final sink = outFile.openWrite();

      int received = 0;
      try {
        await for (final chunk in streamed.stream) {
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

      await outFile.rename('$dir/$lang.db');
      _updateMeta(lang, received);
    } finally {
      client.close();
    }
  }

  // -- Delete --

  Future<void> deletePack(String lang) async {
    final dir = await _packsDir;
    final file = File('$dir/$lang.db');
    if (await file.exists()) await file.delete();

    final packs = _getPacks();
    packs.remove(lang);
    _box.put('packs', packs);
    if (_box.get('last_used') == lang) _box.delete('last_used');
  }

  // -- Local state --

  Map<String, LocalPack> getLocalPacks() {
    final packs = _getPacks();
    return packs.map((lang, data) => MapEntry(
        lang, LocalPack.fromJson(lang, Map<String, dynamic>.from(data as Map))));
  }

  String? get lastUsed => _box.get('last_used') as String?;

  void setLastUsed(String lang) => _box.put('last_used', lang);

  // -- Internals --

  Map<String, dynamic> _getPacks() {
    final raw = _box.get('packs');
    if (raw == null) return {};
    return Map<String, dynamic>.from(raw as Map);
  }

  void _updateMeta(String lang, int sizeBytes) {
    final packs = _getPacks();
    packs[lang] = {
      'schema_version': 1,
      'built_at': DateTime.now().toUtc().toIso8601String(),
      'size_bytes': sizeBytes,
    };
    _box.put('packs', packs);
    _box.put('last_used', lang);
  }
}
