import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/music_manager.dart';
import 'bgm.dart';
import 'bootstrap.dart';
import 'packs.dart';

/// Singleton MusicManager backed by the Hive box and the music directory.
final musicManagerProvider = Provider<MusicManager>((ref) {
  return MusicManager(
    ref.watch(hiveBoxProvider),
    musicDir: ref.watch(musicDirProvider),
  );
});

/// Live music catalog: bundled baseline replaced by `Manifest.music` when
/// the manifest has loaded. The baseline carries the deluxe pack with an
/// empty track list so settings can show *something* before the manifest
/// arrives — the manifest fills in the real track metadata.
final musicCatalogProvider = Provider<List<MusicPackInfo>>((ref) {
  final manifest = ref.watch(manifestProvider);
  return manifest.maybeWhen(
    data: (m) => m.music.isNotEmpty ? m.music : kBaselineMusicCatalog,
    orElse: () => kBaselineMusicCatalog,
  );
});

/// Set of installed music pack IDs. Mutations go through the notifier; the
/// scheduler is reactive to this provider via `bgmSchedulerProvider`.
final installedMusicProvider =
    AsyncNotifierProvider<InstalledMusicNotifier, Set<String>>(
  InstalledMusicNotifier.new,
);

class InstalledMusicNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final mm = ref.read(musicManagerProvider);
    return _readInstalled(mm);
  }

  Future<void> download(String packId) async {
    final mm = ref.read(musicManagerProvider);
    final catalog = ref.read(musicCatalogProvider);
    final info = catalog.firstWhere(
      (p) => p.id == packId,
      orElse: () => throw StateError('Unknown music pack: $packId'),
    );

    ref.read(musicDownloadProgressProvider(packId).notifier).state = 0.0;
    try {
      await mm.downloadPack(
        info,
        onProgress: (p) {
          ref.read(musicDownloadProgressProvider(packId).notifier).state = p;
        },
        onExtracting: () {
          ref.read(musicDownloadProgressProvider(packId).notifier).state = -1.0;
        },
      );
    } finally {
      ref.read(musicDownloadProgressProvider(packId).notifier).state = null;
    }
    state = AsyncData(_readInstalled(mm));
  }

  Future<void> delete(String packId) async {
    final mm = ref.read(musicManagerProvider);
    await mm.deletePack(packId);
    // Drop cached playback positions for this pack so a later reinstall
    // doesn't seek into a stale offset from the now-deleted file.
    ref.read(bgmServiceProvider).forgetPositionsWithPrefix('$packId/');
    state = AsyncData(_readInstalled(mm));
  }

  Set<String> _readInstalled(MusicManager mm) {
    return {
      for (final pack in ref.read(musicCatalogProvider))
        if (mm.isInstalled(pack.id)) pack.id,
    };
  }
}

/// Ephemeral download progress per music pack, keyed by pack id.
/// `null` = idle; `0.0..1.0` = downloading; `-1.0` = extracting.
final musicDownloadProgressProvider = StateProvider.family<double?, String>(
  (ref, packId) => null,
);
