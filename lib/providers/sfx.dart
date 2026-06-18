import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/audio_manager.dart';
import 'settings.dart';

/// Keeps the [AudioManager] SFX singleton in sync with the master + SFX
/// volume sliders.
///
/// SFX volume lives on a process-wide singleton, so the sync must live at the
/// app root rather than on any one screen. Otherwise screens that play SFX
/// without mounting the game (e.g. the egg hatch sequence) would fall back to
/// the singleton's constructor defaults and ignore the player's saved volume.
/// Mounted in `LexawayApp` so it stays alive for the whole app lifetime.
final audioManagerSyncProvider = Provider<void>((ref) {
  void sync() {
    AudioManager.instance.masterVolume = ref.read(masterVolumeProvider);
    AudioManager.instance.sfxVolume = ref.read(sfxVolumeProvider);
  }

  sync();
  ref.listen(masterVolumeProvider, (_, _) => sync());
  ref.listen(sfxVolumeProvider, (_, _) => sync());
}, dependencies: [masterVolumeProvider, sfxVolumeProvider]);
