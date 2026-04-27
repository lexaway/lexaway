import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'bgm_service.dart';

/// Decides which background track plays right now. Main theme on menus;
/// during gameplay we pick a random one-shot track from the pool, reroll
/// when the player crosses a biome boundary, and otherwise let the song
/// finish naturally before swapping to the next random pick. [BgmService]
/// handles the actual crossfade.
class BgmScheduler {
  static const String _mainTheme = 'bgm/bgm_main_theme.m4a';

  /// Pool of gameplay tracks. Originally mapped 1:1 to hours of the day —
  /// the file names persist, but the hour mapping is gone; they're just
  /// 24 ambient loops we shuffle through.
  static const List<String> _gameplayTracks = [
    'bgm/bgm_hour_00.m4a',
    'bgm/bgm_hour_01.m4a',
    'bgm/bgm_hour_02.m4a',
    'bgm/bgm_hour_03.m4a',
    'bgm/bgm_hour_04.m4a',
    'bgm/bgm_hour_05.m4a',
    'bgm/bgm_hour_06.m4a',
    'bgm/bgm_hour_07.m4a',
    'bgm/bgm_hour_08.m4a',
    'bgm/bgm_hour_09.m4a',
    'bgm/bgm_hour_10.m4a',
    'bgm/bgm_hour_11.m4a',
    'bgm/bgm_hour_12.m4a',
    'bgm/bgm_hour_13.m4a',
    'bgm/bgm_hour_14.m4a',
    'bgm/bgm_hour_15.m4a',
    'bgm/bgm_hour_16.m4a',
    'bgm/bgm_hour_17.m4a',
    'bgm/bgm_hour_18.m4a',
    'bgm/bgm_hour_19.m4a',
    'bgm/bgm_hour_20.m4a',
    'bgm/bgm_hour_21.m4a',
    'bgm/bgm_hour_22.m4a',
    'bgm/bgm_hour_23.m4a',
  ];

  /// Minimum time between biome-driven rerolls. Without this, logging in a
  /// few steps from a biome edge — or crossing two narrow zones back to
  /// back — would yank the track before it had a chance to breathe.
  static const Duration _biomeRerollCooldown = Duration(seconds: 60);

  final BgmService service;
  final Random _random;
  StreamSubscription<String>? _completeSub;
  String? _currentGameplayTrack;
  DateTime? _lastSwapAt;
  bool _inGameplay = false;

  BgmScheduler({required this.service, Random? random})
      : _random = random ?? Random() {
    if (kDebugMode) unawaited(_verifyAssets());
    _completeSub = service.onTrackComplete.listen((_) {
      if (_inGameplay) _rollNextTrack();
    });
  }

  /// Play the menu/title theme (looping). Clears the gameplay track so the
  /// next /game entry picks fresh — keeps "fresh session" semantics if the
  /// user uninstalled the active pack and is starting over.
  void startMain() {
    _inGameplay = false;
    _currentGameplayTrack = null;
    service.playLoop(_mainTheme);
  }

  /// Enter gameplay mode and pick a fresh random track to play once through.
  /// When it ends naturally, [BgmService.onTrackComplete] fires and we roll
  /// the next pick. Biome changes preempt this and reroll immediately.
  void startGameplay() {
    _inGameplay = true;
    _rollNextTrack();
  }

  /// Player crossed a biome boundary — reroll, the boundary is the cue.
  /// Suppressed if we just swapped within [_biomeRerollCooldown] so a fresh
  /// track gets time to breathe before another boundary preempts it.
  void onBiomeChanged() {
    if (!_inGameplay) return;
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
    final next = _pickNext();
    _currentGameplayTrack = next;
    _lastSwapAt = DateTime.now();
    service.playLoop(
      next,
      crossfade: const Duration(seconds: 4),
      loop: false,
    );
  }

  String _pickNext() {
    if (_gameplayTracks.length == 1) return _gameplayTracks.first;
    final pool = _currentGameplayTrack == null
        ? _gameplayTracks
        : _gameplayTracks.where((t) => t != _currentGameplayTrack).toList();
    return pool[_random.nextInt(pool.length)];
  }

  /// Debug-only sanity check that every track path in this file is actually
  /// declared in pubspec.yaml and present on disk. The `_gameplayTracks`
  /// list and the asset bundle have to stay in sync by hand; without this,
  /// a typo or missing file only surfaces as silent runtime audio failure.
  Future<void> _verifyAssets() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = manifest.listAssets().toSet();
      for (final track in [..._gameplayTracks, _mainTheme]) {
        final path = 'assets/$track';
        if (!assets.contains(path)) {
          debugPrint('[BgmScheduler] MISSING ASSET: $path');
          assert(false, 'BgmScheduler missing asset: $path');
        }
      }
    } catch (e, s) {
      debugPrint('[BgmScheduler] asset verification failed: $e\n$s');
    }
  }
}
