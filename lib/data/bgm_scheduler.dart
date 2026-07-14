import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';

import '../game/world/world_map.dart';
import 'bgm_service.dart';
import 'music_manager.dart';

/// Decides which background track plays right now.
///
/// Menus loop the bundled main theme. Gameplay picks from a runtime catalog of
/// [ResolvedTrack]s (downloaded music packs), preferring biome-matched tracks
/// and falling back to fillers (empty `biomes`). Empty catalog → gameplay is
/// silent; the main theme is menus-only.
class BgmScheduler {
  /// Bundled main theme — always playable, menus only.
  static const String mainThemeId = 'bgm/bgm_main_theme.m4a';
  static final Source _mainThemeSource = AssetSource(mainThemeId);

  /// Min time between biome-driven rerolls — stops back-to-back boundaries from
  /// yanking a track before it can breathe.
  static const Duration _biomeRerollCooldown = Duration(seconds: 60);

  final BgmService service;
  final Random _random;
  StreamSubscription<String>? _completeSub;

  List<ResolvedTrack> _catalog = const [];
  ResolvedTrack? _currentGameplayTrack;
  BiomeType? _currentBiome;
  DateTime? _lastSwapAt;
  bool _inGameplay = false;

  BgmScheduler({required this.service, Random? random})
      : _random = random ?? Random() {
    _completeSub = service.onTrackComplete.listen((_) {
      if (_inGameplay) _rollNextTrack();
    });
  }

  /// Replace the gameplay catalog (installed music packs changed).
  ///
  /// Normally we let the playing track finish rather than hard-cut on a pack
  /// swap. Two cases force a reroll:
  ///   1. The playing track was removed (pack uninstalled) — its file is gone,
  ///      so retried playback (unmute, resume) would fail silently.
  ///   2. Nothing playing but catalog now non-empty — pack installed
  ///      mid-gameplay; also self-heals any "no track + tracks available" state.
  void setCatalog(List<ResolvedTrack> tracks) {
    _catalog = tracks;
    if (!_inGameplay) return;

    final cur = _currentGameplayTrack;
    if (cur != null) {
      final stillPresent =
          tracks.any((t) => t.identifier == cur.identifier);
      if (!stillPresent) _rollNextTrack();
      return;
    }
    if (tracks.isNotEmpty) _rollNextTrack();
  }

  /// Play the looping menu theme. Clears the gameplay track so the next
  /// gameplay entry picks fresh.
  void startMain() {
    _inGameplay = false;
    _currentGameplayTrack = null;
    service.playLoop(mainThemeId, _mainThemeSource);
  }

  /// Enter gameplay mode and pick a fresh track. Empty catalog → silent.
  void startGameplay() {
    _inGameplay = true;
    _rollNextTrack();
  }

  /// Biome boundary is the reroll cue. Suppressed within [_biomeRerollCooldown]
  /// of the last swap. No-op with an empty catalog.
  void onBiomeChanged(BiomeType current) {
    _currentBiome = current;
    if (!_inGameplay) return;
    if (_catalog.isEmpty) return;
    final last = _lastSwapAt;
    if (last != null &&
        DateTime.now().difference(last) < _biomeRerollCooldown) {
      return;
    }
    _rollNextTrack();
  }

  Future<void> dispose() async {
    await _completeSub?.cancel();
  }

  void _rollNextTrack() {
    if (_catalog.isEmpty) {
      // No pack installed — silent. Stop whatever carried over from the menu.
      _currentGameplayTrack = null;
      service.stop();
      return;
    }

    final next = _pickNext();
    _currentGameplayTrack = next;
    _lastSwapAt = DateTime.now();
    service.playLoop(
      next.identifier,
      next.source,
      crossfade: const Duration(seconds: 4),
      loop: false,
    );
  }

  /// Pick a random candidate for the current biome, avoiding the current track.
  /// Biome-matched tracks share the pool with fillers so abundance favors
  /// matches without forcing exclusivity in thinly-tagged biomes.
  ResolvedTrack _pickNext() {
    final biome = _currentBiome;
    final matched = biome == null
        ? const <ResolvedTrack>[]
        : _catalog
            .where((t) => t.info.biomes.contains(biome.name))
            .toList(growable: false);
    final fillers = _catalog
        .where((t) => t.info.biomes.isEmpty)
        .toList(growable: false);

    final pool = [...matched, ...fillers];
    // Both buckets empty (all tracks biome-tagged, none match) → full catalog.
    final effective = pool.isNotEmpty ? pool : _catalog;

    if (effective.length == 1) return effective.first;

    final filtered = _currentGameplayTrack == null
        ? effective
        : effective
            .where((t) => t.identifier != _currentGameplayTrack!.identifier)
            .toList(growable: false);
    final source = filtered.isEmpty ? effective : filtered;
    return source[_random.nextInt(source.length)];
  }
}
