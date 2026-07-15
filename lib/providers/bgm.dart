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
/// Lifecycle invariant: this provider must outlive [bgmSchedulerProvider],
/// which caches the service via `ref.watch` and listens to its completion
/// stream — rebuilding the service without the scheduler leaves the old one
/// playing while the new one stays silent. Neither has rebuildable deps today;
/// keep it that way unless you also coordinate disposal.
final bgmServiceProvider = Provider<BgmService>((ref) {
  final service = BgmService();
  double effective() =>
      taperedVolume(ref.read(masterVolumeProvider)) *
      taperedVolume(ref.read(bgmVolumeProvider));
  service.setVolume(effective());
  ref.listen<double>(bgmVolumeProvider, (_, _) => service.setVolume(effective()));
  ref.listen<double>(masterVolumeProvider, (_, _) => service.setVolume(effective()));
  ref.onDispose(service.dispose);
  return service;
});

/// Picks which track plays right now (main theme on menus, biome-aware
/// gameplay tracks from installed music packs). Catalog recomputes reactively
/// on pack-set/manifest changes; a swap doesn't yank the current track — the
/// next biome change or song completion pulls from the fresh list.
final bgmSchedulerProvider = Provider<BgmScheduler>((ref) {
  final scheduler = BgmScheduler(service: ref.watch(bgmServiceProvider));

  void refreshCatalog() {
    final mm = ref.read(musicManagerProvider);
    final catalog = ref.read(musicCatalogProvider);
    scheduler.setCatalog(mm.installedTracks(catalog));
  }

  refreshCatalog();
  ref.listen<AsyncValue<Set<String>>>(installedMusicProvider, (_, _) {
    refreshCatalog();
  });
  ref.listen<List<MusicPackInfo>>(musicCatalogProvider, (_, _) {
    refreshCatalog();
  });

  ref.onDispose(scheduler.dispose);
  return scheduler;
});
