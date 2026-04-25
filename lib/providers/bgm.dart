import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bgm_scheduler.dart';
import '../data/bgm_service.dart';
import 'settings.dart';

/// Singleton crossfading BGM player. Listens to the volume slider so the
/// player tracks user changes live.
final bgmServiceProvider = Provider<BgmService>((ref) {
  final service = BgmService();
  service.setVolume(ref.read(bgmVolumeProvider));
  ref.listen<double>(
    bgmVolumeProvider,
    (_, v) => service.setVolume(v),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Picks which track plays right now (main theme on menus, hourly in-game).
final bgmSchedulerProvider = Provider<BgmScheduler>((ref) {
  return BgmScheduler(service: ref.watch(bgmServiceProvider));
});
