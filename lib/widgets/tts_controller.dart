import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/volume_taper.dart';
import '../providers.dart';

/// Widget-owned helper that handles TTS playback and prefetch.
///
/// Owns a generation counter so an in-flight `speak()` can be cancelled by a
/// subsequent question advance — without this, a slow synthesis for the old
/// phrase can arrive after the user has moved on and play over the new one.
class TtsController {
  final WidgetRef ref;
  final bool Function() isMounted;
  int _generation = 0;

  TtsController({required this.ref, required this.isMounted});

  /// Discards any in-flight [speak] request. Call when advancing questions.
  void invalidatePending() => _generation++;

  /// Queue up TTS audio for [texts] so the next playback is instant.
  /// No-op when TTS isn't available for the active lang.
  void prefetch(List<String> texts) {
    final lang = ref.read(activeTtsLangProvider);
    if (lang == null) return;
    ref.read(ttsCacheProvider).prefetch(lang, texts);
  }

  /// Synthesize and play [text]. No-op when TTS isn't available, the widget
  /// has unmounted, or a newer question has superseded this request.
  Future<void> speak(String text) async {
    final lang = ref.read(activeTtsLangProvider);
    if (lang == null) return;
    final gen = _generation;
    final bytes = await ref.read(ttsCacheProvider).getOrGenerate(lang, text);
    if (bytes == null || !isMounted() || gen != _generation) return;
    final masterVol = ref.read(masterVolumeProvider);
    final ttsVol = ref.read(ttsVolumeProvider);
    await ref.read(ttsServiceProvider).playBytes(
      bytes,
      volume: taperedVolume(masterVol) * taperedVolume(ttsVol),
    );
  }
}
