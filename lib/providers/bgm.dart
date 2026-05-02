import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bgm_scheduler.dart';
import '../data/bgm_service.dart';
import '../data/music_manager.dart';
import '../data/volume_taper.dart';
import 'music.dart';
import 'settings.dart';

/// Singleton crossfading BGM player. Listens to both the music slider and the
/// master slider so the player tracks user changes live, and music ducks
/// proportionally with everything else when master is pulled down.
///
/// Lifecycle invariant: this provider must outlive [bgmSchedulerProvider].
/// The scheduler caches the service via `ref.watch` and listens to its
/// completion stream — if the service is rebuilt without rebuilding the
/// scheduler, the old service keeps playing while the new one stays silent.
/// Today neither provider has rebuildable dependencies, so they're stable
/// for the app's lifetime; keep it that way unless you also coordinate
/// disposal.
final bgmServiceProvider = Provider<BgmService>((ref) {
  final service = BgmService();
  double effective() =>
      taperedVolume(ref.read(masterVolumeProvider)) *
      taperedVolume(ref.read(bgmVolumeProvider));
  service.setVolume(effective());
  ref.listen<double>(bgmVolumeProvider, (_, __) => service.setVolume(effective()));
  ref.listen<double>(masterVolumeProvider, (_, __) => service.setVolume(effective()));
  ref.onDispose(service.dispose);
  return service;
});

/// Picks which track plays right now (main theme on menus, biome-aware
/// gameplay tracks from installed music packs in `/game`). The catalog is
/// recomputed reactively whenever the installed pack set or the manifest
/// catalog changes — the scheduler doesn't yank the current track when the
/// catalog swaps; the next biome change or song completion pulls from the
/// fresh list.
final bgmSchedulerProvider = Provider<BgmScheduler>((ref) {
  final scheduler = BgmScheduler(service: ref.watch(bgmServiceProvider));

  void refreshCatalog() {
    final mm = ref.read(musicManagerProvider);
    final catalog = ref.read(musicCatalogProvider);
    scheduler.setCatalog(mm.installedTracks(catalog));
  }

  refreshCatalog();
  ref.listen<AsyncValue<Set<String>>>(installedMusicProvider, (_, __) {
    refreshCatalog();
  });
  ref.listen<List<MusicPackInfo>>(musicCatalogProvider, (_, __) {
    refreshCatalog();
  });

  ref.onDispose(scheduler.dispose);
  return scheduler;
});
