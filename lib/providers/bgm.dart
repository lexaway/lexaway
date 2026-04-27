import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bgm_scheduler.dart';
import '../data/bgm_service.dart';
import '../data/volume_taper.dart';
import 'settings.dart';

/// Singleton crossfading BGM player. Listens to both the music slider and the
/// master slider so the player tracks user changes live, and music ducks
/// proportionally with everything else when master is pulled down.
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

/// Picks which track plays right now (main theme on menus, random one-shot
/// gameplay tracks in /game with biome-driven rerolls).
final bgmSchedulerProvider = Provider<BgmScheduler>((ref) {
  final scheduler = BgmScheduler(service: ref.watch(bgmServiceProvider));
  ref.onDispose(scheduler.dispose);
  return scheduler;
});
