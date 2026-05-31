import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bgm_service.dart';
import '../data/volume_taper.dart';
import 'settings.dart';

/// How loud the ambient bed sits relative to the rest of the SFX layer. The
/// bed is continuous background texture, so it stays well under the one-shots
/// and music. Tune by ear.
const double _ambientGain = 0.7;

/// Looping environmental ambience (e.g. distant ocean waves on the coast).
///
/// Reuses [BgmService] purely as a crossfading looping player — it already
/// owns the fade ramps, the TTS duck, and the lifecycle pause/resume we need.
/// Its track-position cache and completion stream are inert for an infinite
/// loop, so nothing there fights us. Volume follows the **SFX** tier
/// (master × sfx), not music: the bed is a world sound, so pulling the SFX
/// slider down — or to zero — quiets it like footsteps.
///
/// The bed itself is chosen per-biome via `BiomeDefinition.ambientLoop` and
/// driven from the game screen's `BiomeChanged` handler.
final ambientServiceProvider = Provider<BgmService>((ref) {
  final service = BgmService();
  double effective() =>
      taperedVolume(ref.read(masterVolumeProvider)) *
      taperedVolume(ref.read(sfxVolumeProvider)) *
      _ambientGain;
  service.setVolume(effective());
  ref.listen<double>(sfxVolumeProvider, (_, __) => service.setVolume(effective()));
  ref.listen<double>(masterVolumeProvider, (_, __) => service.setVolume(effective()));
  ref.onDispose(service.dispose);
  return service;
});
