import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive_ce.dart';

import 'content_urls.dart';
import 'download_helper.dart';
import 'hive_keys.dart';

/// One playable track inside a music pack. `biomes` empty means "filler" —
/// it's eligible to play in any biome when there are no biome-specific
/// matches available.
class TrackInfo {
  final String id;
  final String file;
  final String title;
  final List<String> biomes;
  final List<String> tags;
  final bool loopable;

  const TrackInfo({
    required this.id,
    required this.file,
    required this.title,
    this.biomes = const [],
    this.tags = const [],
    this.loopable = true,
  });

  static TrackInfo? tryFromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final file = json['file'];
    final title = json['title'];
    if (id is! String || file is! String || title is! String) return null;
    return TrackInfo(
      id: id,
      file: file,
      title: title,
      biomes: _stringList(json['biomes']),
      tags: _stringList(json['tags']),
      loopable: switch (json['loopable']) {
        final bool b => b,
        _ => true,
      },
    );
  }

  static List<String> _stringList(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final v in raw)
        if (v is String) v,
    ];
  }
}

/// One downloadable music pack — a tarball containing every track in [tracks]
/// at its top level. Naming mirrors `TtsModelInfo`: `archive_name` is the
/// stem used for both the remote `.tar.bz2` artifact and the local extraction
/// directory.
class MusicPackInfo {
  final String id;
  final String displayName;
  final String archiveName;
  final int approximateSizeMB;
  final List<TrackInfo> tracks;

  const MusicPackInfo({
    required this.id,
    required this.displayName,
    required this.archiveName,
    required this.approximateSizeMB,
    required this.tracks,
  });

  static MusicPackInfo? tryFromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final displayName = json['display_name'];
    final archiveName = json['archive_name'];
    final size = json['approximate_size_mb'];
    final rawTracks = json['tracks'];
    if (id is! String ||
        displayName is! String ||
        archiveName is! String ||
        size is! int ||
        rawTracks is! List) {
      return null;
    }
    final tracks = <TrackInfo>[];
    for (final t in rawTracks) {
      if (t is! Map) continue;
      final track = TrackInfo.tryFromJson(Map<String, dynamic>.from(t));
      if (track != null) tracks.add(track);
    }
    return MusicPackInfo(
      id: id,
      displayName: displayName,
      archiveName: archiveName,
      approximateSizeMB: size,
      tracks: tracks,
    );
  }
}

/// A track that is *currently installed on disk* and ready to hand to
/// [BgmService.playLoop]. The [identifier] is what BgmService keys position
/// tracking and `onTrackComplete` on, so it must stay stable per-track across
/// rebuilds of the catalog.
class ResolvedTrack {
  final TrackInfo info;
  final String packId;
  final Source source;
  final String identifier;

  const ResolvedTrack({
    required this.info,
    required this.packId,
    required this.source,
    required this.identifier,
  });
}

/// Bundled-baseline catalog. Lets the settings screen render the deluxe
/// pack tile before the remote manifest has loaded — same idea as
/// `kBaselineVoiceCatalog`. The manifest's `music` array overrides this when
/// it arrives.
const kBaselineMusicCatalog = <MusicPackInfo>[
  MusicPackInfo(
    id: 'towballs_crossing_deluxe',
    displayName: "Towball's Crossing Deluxe",
    archiveName: 'music-towballs-crossing-deluxe-v1',
    approximateSizeMB: 77,
    tracks: [],
  ),
];

class MusicManager {
  final Box _box;
  final String musicDir;

  /// Guards against concurrent downloads of the same pack.
  final _activeDownloads = <String, Future<void>>{};

  MusicManager(this._box, {required this.musicDir});

  bool isInstalled(String packId) => _getInstalled().containsKey(packId);

  /// Absolute filesystem path to the directory holding the pack's track
  /// files, or null if the pack isn't installed.
  String? packDir(String packId) {
    final entry = _getInstalled()[packId];
    if (entry == null) return null;
    final archiveName = (entry as Map)['archive_name'] as String?;
    if (archiveName == null) return null;
    return '$musicDir/$archiveName';
  }

  Future<void> downloadPack(
    MusicPackInfo info, {
    void Function(double)? onProgress,
    void Function()? onExtracting,
  }) async {
    if (isInstalled(info.id)) return;
    if (_activeDownloads.containsKey(info.id)) return;

    final future = _doDownloadPack(
      info,
      onProgress: onProgress,
      onExtracting: onExtracting,
    );
    _activeDownloads[info.id] = future;
    try {
      await future;
    } finally {
      _activeDownloads.remove(info.id);
    }
  }

  Future<void> _doDownloadPack(
    MusicPackInfo info, {
    void Function(double)? onProgress,
    void Function()? onExtracting,
  }) async {
    await Directory(musicDir).create(recursive: true);

    final tmpPath = '$musicDir/${info.archiveName}.tar.bz2.tmp';
    try {
      final url = await packsUrl('${info.archiveName}.tar.bz2');
      await downloadToFile(url, tmpPath, onProgress: onProgress);
      onExtracting?.call();
      // Tarball entries are flat (top-level slug.m4a); extract into the
      // pack-specific directory so [packDir]/[installedTracks] can find them.
      await extractTarBz2InIsolate(tmpPath, '$musicDir/${info.archiveName}');
      await File(tmpPath).delete();
    } catch (_) {
      final partial = Directory('$musicDir/${info.archiveName}');
      if (await partial.exists()) await partial.delete(recursive: true);
      final tmp = File(tmpPath);
      if (await tmp.exists()) await tmp.delete();
      rethrow;
    }

    final installed = _getInstalled();
    installed[info.id] = {
      'archive_name': info.archiveName,
      'downloaded_at': DateTime.now().toUtc().toIso8601String(),
    };
    _box.put(HiveKeys.musicPacks, installed);
  }

  Future<void> deletePack(String packId) async {
    final installed = _getInstalled();
    final entry = installed[packId];
    if (entry == null) return;

    final archiveName = (entry as Map)['archive_name'] as String?;
    if (archiveName != null) {
      final dir = Directory('$musicDir/$archiveName');
      if (await dir.exists()) await dir.delete(recursive: true);
    }

    installed.remove(packId);
    _box.put(HiveKeys.musicPacks, installed);
  }

  /// Resolve every installed track in [catalog] to a [ResolvedTrack]. Tracks
  /// whose files are missing on disk are silently skipped — defensive against
  /// partial-extraction state without forcing callers to handle nulls.
  List<ResolvedTrack> installedTracks(List<MusicPackInfo> catalog) {
    final out = <ResolvedTrack>[];
    for (final pack in catalog) {
      if (!isInstalled(pack.id)) continue;
      final dir = packDir(pack.id);
      if (dir == null) continue;
      for (final track in pack.tracks) {
        final filePath = '$dir/${track.file}';
        if (!File(filePath).existsSync()) {
          if (kDebugMode) {
            debugPrint('[MusicManager] missing on disk: $filePath');
          }
          continue;
        }
        out.add(ResolvedTrack(
          info: track,
          packId: pack.id,
          source: DeviceFileSource(filePath),
          identifier: '${pack.id}/${track.id}',
        ));
      }
    }
    return out;
  }

  Map<String, dynamic> _getInstalled() {
    final raw = _box.get(HiveKeys.musicPacks);
    if (raw == null) return {};
    return Map<String, dynamic>.from(raw as Map);
  }

}
