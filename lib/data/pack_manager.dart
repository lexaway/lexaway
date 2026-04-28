import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:http/http.dart' as http;
import 'package:sqlite_async/sqlite_async.dart';

import 'content_urls.dart';
import 'download_helper.dart';
import 'hive_keys.dart';
import 'tts_manager.dart';

/// Pack IDs are `<fromLang>-<lang>`. Both halves are ISO 639-3 codes today
/// (always 3 letters, no internal hyphens). The split is exposed via this
/// helper so future code that relaxes the format — script tags, region tags,
/// versioned IDs — only has to update one place.
({String fromLang, String lang}) parsePackId(String packId) {
  final i = packId.indexOf('-');
  if (i < 0) {
    throw ArgumentError.value(packId, 'packId', 'expected "<fromLang>-<lang>"');
  }
  return (fromLang: packId.substring(0, i), lang: packId.substring(i + 1));
}

String formatPackId({required String fromLang, required String lang}) =>
    '$fromLang-$lang';

// Schema-compatibility window for local pack files on disk.
//
// ⚠️  BUMP BOTH IN LOCKSTEP on breaking schema changes. When the on-disk
// pack schema rev's (e.g. v1 → v2), set BOTH constants to 2.
//
// Why: a config like `min = 1, max = 2` makes a v1 local pack appear
// "supported" (`1 >= 1 && 1 <= 2` → upToDate), so the gate in
// `_openAndLoad` sleeps and v2 SQL runs against a v1 file. The query
// throws, the destructive catch fires, and the offline user loses their
// pack before they can re-download. The whole point of this gate is to
// prevent exactly that — don't defeat it by trying to "keep backwards
// compat" on a breaking change.
//
// Additive changes (a new nullable column the app tolerates) MAY widen
// the window by bumping only `max`. Breaking changes MUST NOT.
//
// See `test/open_and_load_gate_test.dart` for the gate's live behavior
// and `packUpdateStatus` below for the precedence rules.
const minSupportedPackSchema = 1;
const maxSupportedPackSchema = 1;

enum PackUpdateStatus {
  notDownloaded,
  upToDate,
  updateAvailable,
  appUpdateRequired,
  localOutdated,
}

PackUpdateStatus packUpdateStatus(
  PackInfo remote,
  LocalPack? local, {
  int min = minSupportedPackSchema,
  int max = maxSupportedPackSchema,
}) {
  if (local == null) return PackUpdateStatus.notDownloaded;
  if (remote.schemaVersion > max) return PackUpdateStatus.appUpdateRequired;
  if (local.schemaVersion < min || local.schemaVersion > max) {
    return PackUpdateStatus.localOutdated;
  }
  if (remote.builtAt != local.builtAt) return PackUpdateStatus.updateAvailable;
  return PackUpdateStatus.upToDate;
}

/// Local-only status — works offline without a manifest.
/// Used by `_openAndLoad` to gate pack opening on schema compatibility.
PackUpdateStatus localPackStatus(
  LocalPack? local, {
  int min = minSupportedPackSchema,
  int max = maxSupportedPackSchema,
}) {
  if (local == null) return PackUpdateStatus.notDownloaded;
  if (local.schemaVersion < min || local.schemaVersion > max) {
    return PackUpdateStatus.localOutdated;
  }
  return PackUpdateStatus.upToDate;
}

class PackInfo {
  final String lang;
  final String fromLang;
  final String name;
  final String flag;
  final String builtAt;
  final int schemaVersion;

  const PackInfo({
    required this.lang,
    required this.fromLang,
    required this.name,
    required this.flag,
    required this.builtAt,
    required this.schemaVersion,
  });

  String get packId => formatPackId(fromLang: fromLang, lang: lang);

  factory PackInfo.fromJson(Map<String, dynamic> json) => PackInfo(
    lang: json['lang'] as String,
    fromLang: json['from_lang'] as String,
    name: json['name'] as String,
    flag: json['flag'] as String,
    builtAt: json['built_at'] as String,
    schemaVersion: json['schema_version'] as int,
  );
}

class LocalPack {
  final String lang;
  final String fromLang;
  final int schemaVersion;
  final String builtAt;
  final int sizeBytes;

  const LocalPack({
    required this.lang,
    required this.fromLang,
    required this.schemaVersion,
    required this.builtAt,
    required this.sizeBytes,
  });

  String get packId => formatPackId(fromLang: fromLang, lang: lang);

  factory LocalPack.fromJson(String packId, Map<String, dynamic> json) {
    final parsed = parsePackId(packId);
    return LocalPack(
      lang: parsed.lang,
      fromLang: parsed.fromLang,
      schemaVersion: json['schema_version'] as int,
      builtAt: json['built_at'] as String,
      sizeBytes: json['size_bytes'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'built_at': builtAt,
    'size_bytes': sizeBytes,
  };
}

class Manifest {
  final int schemaVersion;
  final List<PackInfo> packs;

  /// Optional remote-driven TTS voice catalog, keyed by ISO 639-3 lang code.
  /// When a lang appears here, it overrides the bundled baseline; absent langs
  /// fall back to the baseline. Empty list = "this lang has no voices."
  final Map<String, List<TtsModelInfo>> voices;

  const Manifest({
    required this.schemaVersion,
    required this.packs,
    this.voices = const {},
  });

  List<PackInfo> packsFor(String fromLang) =>
      packs.where((p) => p.fromLang == fromLang).toList();

  factory Manifest.fromJson(Map<String, dynamic> json) => Manifest(
    schemaVersion: json['schema_version'] as int,
    packs: (json['packs'] as List)
        .map((p) => PackInfo.fromJson(p as Map<String, dynamic>))
        .toList(),
    voices: _parseVoices(json['voices']),
  );

  static Map<String, List<TtsModelInfo>> _parseVoices(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, List<TtsModelInfo>>{};
    raw.forEach((lang, list) {
      if (lang is! String || list is! List) {
        if (kDebugMode) debugPrint('Manifest voices: skipping bad entry $lang');
        return;
      }
      final voices = <TtsModelInfo>[];
      for (final v in list) {
        if (v is! Map) {
          if (kDebugMode) debugPrint('Manifest voices[$lang]: non-map entry $v');
          continue;
        }
        final info = TtsModelInfo.tryFromJson(Map<String, dynamic>.from(v));
        if (info == null) {
          if (kDebugMode) debugPrint('Manifest voices[$lang]: malformed $v');
          continue;
        }
        voices.add(info);
      }
      out[lang] = voices;
    });
    return out;
  }
}

class PackManager {
  final Box _box;
  final String packsDir;

  PackManager(this._box, {required this.packsDir});

  Future<Manifest> fetchManifest() async {
    try {
      final url = await packsUrl('manifest.json');
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        _box.put(HiveKeys.manifestCache, response.body);
        return Manifest.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      // Fall through to cached version
    }

    final cached = _box.get(HiveKeys.manifestCache) as String?;
    if (cached != null) {
      try {
        return Manifest.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      } catch (_) {
        _box.delete(HiveKeys.manifestCache);
      }
    }

    throw Exception('No manifest available (network failed, no cache)');
  }

  Future<void> downloadPack(
    String lang, {
    required String fromLang,
    void Function(double)? onProgress,
  }) async {
    final packId = formatPackId(fromLang: fromLang, lang: lang);
    final dir = packsDir;
    await Directory(dir).create(recursive: true);

    final tmpPath = '$dir/$packId.db.tmp';
    final url = await packsUrl('$packId.db');
    await downloadToFile(
      url,
      tmpPath,
      onProgress: onProgress,
    );

    final sizeBytes = await File(tmpPath).length();
    await File(tmpPath).rename('$dir/$packId.db');
    await _updateMeta(packId, sizeBytes);
  }

  Future<void> deletePack(String packId) async {
    final dir = packsDir;
    final file = File('$dir/$packId.db');
    if (await file.exists()) await file.delete();

    final packs = _getPacks();
    packs.remove(packId);
    _box.put(HiveKeys.packs, packs);
    if (_box.get(HiveKeys.lastUsed) == packId) _box.delete(HiveKeys.lastUsed);
  }

  Map<String, LocalPack> getLocalPacks() {
    final packs = _getPacks();
    return packs.map(
      (packId, data) => MapEntry(
        packId,
        LocalPack.fromJson(packId, Map<String, dynamic>.from(data as Map)),
      ),
    );
  }

  /// Returns the packId of the last-used pack (e.g. "eng-fra").
  String? get lastUsed => _box.get(HiveKeys.lastUsed) as String?;

  void setLastUsed(String packId) => _box.put(HiveKeys.lastUsed, packId);

  Map<String, dynamic> _getPacks() {
    final raw = _box.get(HiveKeys.packs);
    if (raw == null) return {};
    return Map<String, dynamic>.from(raw as Map);
  }

  Future<void> _updateMeta(String packId, int sizeBytes) async {
    final dbPath = '$packsDir/$packId.db';
    final db = SqliteDatabase(path: dbPath);
    try {
      final rows = await db.getAll(
        "SELECT key, value FROM meta WHERE key IN ('built_at', 'schema_version')",
      );
      final meta = {for (final r in rows) r['key'] as String: r['value'] as String};

      final packs = _getPacks();
      packs[packId] = {
        // Default to 0 — outside every supported window — so a pipeline bug
        // that omits `meta.schema_version` produces a loud `localOutdated`
        // recovery instead of silently masquerading as whatever the current
        // schema happens to be.
        'schema_version': int.parse(meta['schema_version'] ?? '0'),
        'built_at': meta['built_at'] ?? '',
        'size_bytes': sizeBytes,
      };
      _box.put(HiveKeys.packs, packs);
      _box.put(HiveKeys.lastUsed, packId);
    } finally {
      await db.close();
    }
  }
}
