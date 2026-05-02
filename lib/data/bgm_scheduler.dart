import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';

import '../game/world/world_map.dart';
import 'bgm_service.dart';
import 'music_manager.dart';

/// Decides which background track plays right now.
///
/// On menus we loop the bundled main theme. During gameplay we maintain a
/// runtime catalog of [ResolvedTrack]s sourced from whichever music packs
/// the user has downloaded — picking biome-matched tracks for the current
/// biome, falling back to "filler" tracks (empty `biomes` list) when no
/// match is available. When the catalog is empty (no music pack installed),
/// gameplay is silent — the main theme is reserved for menus.
class BgmScheduler {
  /// Bundled main-theme identifier and source. Always playable, no download
  /// required. Plays on menus only — gameplay without a music pack installed
  /// stays silent.
  static const String mainThemeId = 'bgm/bgm_main_theme.m4a';
  static final Source _mainThemeSource = AssetSource(mainThemeId);

  /// Minimum time between biome-driven rerolls. Without this, logging in a
  /// few steps from a biome edge — or crossing two narrow zones back to
  /// back — would yank the track before it had a chance to breathe.
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

  /// Replace the gameplay catalog. Called by the Riverpod wiring whenever
  /// the installed music packs change.
  ///
  /// In gameplay we're conservative about yanking the playing track — letting
  /// it finish naturally feels less disruptive than a hard cut on every pack
  /// swap. But two cases force a reroll:
  ///   1. The currently-playing track was just removed (pack uninstalled
  ///      mid-gameplay) — its file is gone from disk, so anything that
  ///      retries playback (volume unmute, app resume) would fail silently.
  ///   2. We were previously stuck on the main-theme fallback because the
  ///      catalog was empty and now it isn't — the user just installed a
  ///      pack mid-gameplay and would expect to hear it.
  void setCatalog(List<ResolvedTrack> tracks) {
    final wasEmpty = _catalog.isEmpty;
    _catalog = tracks;
    if (!_inGameplay) return;

    final cur = _currentGameplayTrack;
    if (cur != null) {
      final stillPresent =
          tracks.any((t) => t.identifier == cur.identifier);
      if (!stillPresent) _rollNextTrack();
      return;
    }
    // No gameplay track was active (we were on the main-theme fallback) —
    // if a pack just appeared, kick off a real gameplay roll.
    if (wasEmpty && tracks.isNotEmpty) _rollNextTrack();
  }

  /// Play the menu/title theme (looping). Clears the gameplay track so the
  /// next `/game` entry picks fresh — keeps "fresh session" semantics if the
  /// user uninstalled a music pack and is starting over.
  void startMain() {
    _inGameplay = false;
    _currentGameplayTrack = null;
    service.playLoop(mainThemeId, _mainThemeSource);
  }

  /// Enter gameplay mode and pick a fresh track. With a populated catalog,
  /// picks a one-shot from the biome-appropriate pool. With an empty catalog
  /// (no music pack installed), gameplay is silent.
  void startGameplay() {
    _inGameplay = true;
    _rollNextTrack();
  }

  /// Player crossed a biome boundary — reroll, the boundary is the cue.
  /// Suppressed if we just swapped within [_biomeRerollCooldown] so a fresh
  /// track gets time to breathe before another boundary preempts it. Also a
  /// no-op when no music pack is installed (catalog empty) — the main theme
  /// is already a single looping track.
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
      // No pack installed — gameplay is silent. Stop whatever was playing
      // (likely the main theme that carried over from the menu).
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

  /// Build a pool of candidates for the current biome and pick one at random,
  /// avoiding the currently-playing track when possible. Biome-matched tracks
  /// share the pool with fillers — abundance favors biome matches naturally
  /// (more tagged tracks → higher pick odds), without forcing exclusivity in
  /// biomes that have only a track or two of their own.
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
    // Fall back to the full catalog if both buckets are empty (e.g. every
    // installed track is biome-tagged and none match the current biome).
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
