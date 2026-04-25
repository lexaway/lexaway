import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'bgm_service.dart';

/// Decides which background track plays right now. Main theme on menus;
/// during gameplay we pick a random track from the pool, reroll on biome
/// change, and rotate every [_rotationInterval] as a fallback so a player
/// who lingers in one biome still hears variety. [BgmService] handles the
/// actual crossfade.
class BgmScheduler {
  static const String _mainTheme = 'bgm/bgm_main_theme.m4a';
  static const Duration _rotationInterval = Duration(minutes: 6);

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

  final BgmService service;
  final Random _random;
  Timer? _rotationTimer;
  String? _currentGameplayTrack;
  bool _inGameplay = false;

  BgmScheduler({required this.service, Random? random})
      : _random = random ?? Random() {
    if (kDebugMode) unawaited(_verifyAssets());
  }

  /// Play the menu/title theme. No-op if it's already playing. Clears the
  /// gameplay track so the next /game entry picks fresh — keeps "fresh
  /// session" semantics if the user uninstalled the active pack and is
  /// starting over with a different one.
  void startMain() {
    _rotationTimer?.cancel();
    _rotationTimer = null;
    _inGameplay = false;
    _currentGameplayTrack = null;
    service.playLoop(_mainTheme);
  }

  /// Enter gameplay mode and pick a fresh random track. Position is
  /// preserved by [BgmService] per asset, so if the random pick happens to
  /// be a track the user heard before, it resumes from where it left off.
  void startGameplay() {
    _inGameplay = true;
    _rollNextTrack();
  }

  /// Player crossed a biome boundary. Reroll to a new track and reset the
  /// rotation timer — the boundary itself counts as variety.
  void onBiomeChanged() {
    if (!_inGameplay) return;
    _rollNextTrack();
  }

  /// Re-evaluate after the app comes back to foreground. Dart timers don't
  /// fire while the app is suspended, so a long background nap leaves the
  /// rotation timer stuck. Re-arm fresh from the moment the user returns.
  void onAppResumed() {
    if (!_inGameplay) return;
    _restartRotationTimer();
  }

  void _rollNextTrack() {
    final next = _pickNext();
    _currentGameplayTrack = next;
    service.playLoop(next, crossfade: const Duration(seconds: 4));
    _restartRotationTimer();
  }

  String _pickNext() {
    if (_gameplayTracks.length == 1) return _gameplayTracks.first;
    final pool = _currentGameplayTrack == null
        ? _gameplayTracks
        : _gameplayTracks.where((t) => t != _currentGameplayTrack).toList();
    return pool[_random.nextInt(pool.length)];
  }

  void _restartRotationTimer() {
    _rotationTimer?.cancel();
    _rotationTimer = Timer(_rotationInterval, _onRotationTimer);
  }

  void _onRotationTimer() {
    if (!_inGameplay) return;
    _rollNextTrack();
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
