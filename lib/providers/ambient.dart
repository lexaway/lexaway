import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bgm_service.dart';
import '../data/volume_taper.dart';
import 'settings.dart';

/// Ambient bed gain relative to the SFX layer. Continuous texture, so it sits
/// well under the one-shots. Tune by ear.
const double _ambientGain = 0.7;

/// Looping environmental ambience (e.g. distant ocean waves on the coast).
///
/// Reuses [BgmService] as a crossfading looping player — it already owns the
/// fade ramps, TTS duck, and lifecycle pause/resume; its position cache and
/// completion stream are inert for an infinite loop. Volume follows the SFX
/// tier (master × sfx), not music: the bed is a world sound, so the SFX slider
/// quiets it like footsteps.
///
/// The bed is chosen per-biome via `BiomeDefinition.ambientLoop`, driven from
/// the game screen's `BiomeChanged` handler.
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
