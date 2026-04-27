import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Crossfading background music player.
///
/// Owns two [AudioPlayer] instances that swap roles on every track change so
/// transitions can fade out the old track while the new one fades in. Volume
/// is the product of [setVolume] (user slider) and a duck multiplier driven
/// by [setDucking] (TTS overlay).
class BgmService {
  static const double _duckMultiplier = 0.3;
  static const Duration _rampInterval = Duration(milliseconds: 50);

  AudioPlayer _current = AudioPlayer(playerId: 'bgm_a');
  AudioPlayer _previous = AudioPlayer(playerId: 'bgm_b');

  String? _currentAsset;
  double _userVolume = 1.0;
  bool _ducking = false;
  bool _paused = false;

  double _currentVol = 0;
  double _previousVol = 0;

  /// Last known playback position per asset, captured whenever we crossfade
  /// away. Lets users hop into Settings and back without losing their place
  /// in the hourly track.
  final Map<String, Duration> _positions = {};

  /// Serializes [playLoop] calls. Without this, two rapid invocations could
  /// both pass the same-asset early-return and race through the swap/play
  /// dance with the dual-player invariant broken.
  Future<void>? _transitionLock;

  int _transitionId = 0;
  Timer? _rampTimer;
  Timer? _duckRampTimer;

  /// Fires the asset path of a non-looping track when it reaches its natural
  /// end. The scheduler uses this to pick the next gameplay track only at
  /// song boundaries, instead of cutting in mid-phrase on a timer.
  final StreamController<String> _completeCtrl =
      StreamController<String>.broadcast();
  Stream<String> get onTrackComplete => _completeCtrl.stream;

  StreamSubscription<void>? _completeSub;

  BgmService() {
    _current.setReleaseMode(ReleaseMode.loop);
    _previous.setReleaseMode(ReleaseMode.loop);
  }

  double _effectiveVolume() =>
      (_userVolume * (_ducking ? _duckMultiplier : 1.0)).clamp(0.0, 1.0);

  /// Crossfade to [asset] (relative to `assets/`, e.g. `bgm/bgm_main_theme.m4a`).
  /// No-op if it's already the active asset. If the asset has been played
  /// before, resumes from the saved position.
  ///
  /// When [loop] is false, the track plays once through and emits on
  /// [onTrackComplete] when finished — letting callers chain to a follow-up
  /// asset only at the natural end. Defaults to true for menu loops.
  Future<void> playLoop(
    String asset, {
    Duration crossfade = const Duration(milliseconds: 1500),
    bool loop = true,
  }) async {
    final prev = _transitionLock;
    final completer = Completer<void>();
    _transitionLock = completer.future;

    try {
      await prev;
      if (asset == _currentAsset) return;

      final outgoingAsset = _currentAsset;
      if (outgoingAsset != null) {
        final pos = await _current.getCurrentPosition();
        if (pos != null) _positions[outgoingAsset] = pos;
      }

      _currentAsset = asset;
      if (_paused) return; // resume() will start it

      final id = ++_transitionId;
      _rampTimer?.cancel();
      _duckRampTimer?.cancel();

      // Stop whatever was already on the outgoing slot before reusing it.
      await _previous.stop();

      // Swap: outgoing keeps fading from its current vol; incoming starts at 0.
      final swap = _current;
      _current = _previous;
      _previous = swap;

      _previousVol = _currentVol;
      _currentVol = 0;

      final releaseMode = loop ? ReleaseMode.loop : ReleaseMode.stop;
      await _current.setReleaseMode(releaseMode);
      await _current.setVolume(0);

      // audioplayers' _completePrepared waits for a platform "prepared" event
      // that occasionally never fires on iOS — the bare await would hang for
      // 30s and surface as an unhandled TimeoutException. Wrap with our own
      // 5s timeout, throw the stuck player away, and retry once with a fresh
      // instance.
      if (!await _tryPlay(_current, asset)) {
        final stuck = _current;
        unawaited(() async {
          // stop() first so a late-arriving prepared event doesn't briefly
          // emit audio between play() resolving and dispose() landing.
          try {
            await stuck.stop().timeout(const Duration(seconds: 1));
          } catch (_) {}
          try {
            await stuck.dispose();
          } catch (_) {}
        }());
        _current = AudioPlayer();
        await _current.setReleaseMode(releaseMode);
        await _current.setVolume(0);
        // Lifecycle could have flipped to paused during the awaits above;
        // bail without starting audio if so. resume() will redo this leg.
        if (_paused) return;
        await _tryPlay(_current, asset);
      }

      final savedPos = _positions[asset];
      if (savedPos != null) {
        try {
          await _current
              .seek(savedPos)
              .timeout(const Duration(seconds: 2));
        } catch (_) {
          // Seek didn't complete in time; live with starting at 0.
        }
      }

      // Re-attach the completion listener to whichever player is now
      // _current (post-swap, possibly post-recovery). Looping tracks
      // never fire onPlayerComplete, so only subscribe for one-shot loops.
      _completeSub?.cancel();
      _completeSub = null;
      if (!loop) {
        final completedAsset = asset;
        _completeSub = _current.onPlayerComplete.listen((_) {
          if (_currentAsset == completedAsset) {
            _completeCtrl.add(completedAsset);
          }
        });
      }

      _runRamp(id: id, duration: crossfade);
    } finally {
      completer.complete();
      if (_transitionLock == completer.future) _transitionLock = null;
    }
  }

  /// User-facing volume (0..1). Updated live as the slider moves.
  void setVolume(double v) {
    _userVolume = v.clamp(0.0, 1.0);
    _pushVolumeIfIdle();
  }

  /// Toggle the TTS-driven duck. Going *down* is instant — a ramp would lag
  /// behind a short utterance. Coming back *up* eases over ~300ms so the
  /// music doesn't pop in at full volume the moment TTS finishes.
  void setDucking(bool ducking) {
    if (_ducking == ducking) return;
    _ducking = ducking;
    if (_currentAsset == null || _paused) return;
    if (_rampTimer != null && _rampTimer!.isActive) return;
    if (ducking) {
      _duckRampTimer?.cancel();
      _currentVol = _effectiveVolume();
      _current.setVolume(_currentVol);
    } else {
      _runDuckRamp();
    }
  }

  /// Pause both players. Idempotent. Used on app backgrounding.
  Future<void> pause() async {
    if (_paused) return;
    _paused = true;
    _rampTimer?.cancel();
    _duckRampTimer?.cancel();
    await _current.pause();
    await _previous.pause();
  }

  /// Resume the active asset. If `playLoop` was called while paused, this
  /// kicks off the deferred play instead. A pause taken mid-crossfade won't
  /// resume the outgoing track — it stays silent and gets cleaned up on the
  /// next [playLoop].
  Future<void> resume() async {
    if (!_paused) return;
    _paused = false;
    final asset = _currentAsset;
    if (asset == null) return;

    if (_currentVol == 0 && _previousVol == 0) {
      // We never actually started — playLoop deferred during pause.
      _currentAsset = null; // force playLoop to do its thing
      await playLoop(asset);
    } else {
      _currentVol = _effectiveVolume();
      await _current.setVolume(_currentVol);
      await _current.resume();
    }
  }

  Future<void> dispose() async {
    _rampTimer?.cancel();
    _duckRampTimer?.cancel();
    await _completeSub?.cancel();
    await _completeCtrl.close();
    await _current.dispose();
    await _previous.dispose();
  }

  Future<bool> _tryPlay(AudioPlayer player, String asset) async {
    try {
      await player
          .play(AssetSource(asset))
          .timeout(const Duration(seconds: 5));
      return true;
    } on TimeoutException {
      return false;
    } catch (e, s) {
      debugPrint('[BgmService] play("$asset") failed: $e\n$s');
      return false;
    }
  }

  void _runRamp({required int id, required Duration duration}) {
    final startCurr = _currentVol;
    final startPrev = _previousVol;
    final steps =
        (duration.inMilliseconds / _rampInterval.inMilliseconds).ceil().clamp(1, 1000);
    var step = 0;

    _rampTimer = Timer.periodic(_rampInterval, (timer) async {
      if (id != _transitionId) {
        timer.cancel();
        return;
      }
      step++;
      final t = (step / steps).clamp(0.0, 1.0);

      _currentVol = startCurr + (_effectiveVolume() - startCurr) * t;
      _previousVol = startPrev * (1 - t);

      await _current.setVolume(_currentVol);
      await _previous.setVolume(_previousVol);

      if (step >= steps) {
        timer.cancel();
        await _previous.stop();
        _previousVol = 0;
      }
    });
  }

  Future<void> _pushVolumeIfIdle() async {
    if (_currentAsset == null || _paused) return;
    if (_rampTimer != null && _rampTimer!.isActive) return;
    if (_duckRampTimer != null && _duckRampTimer!.isActive) return;
    _currentVol = _effectiveVolume();
    await _current.setVolume(_currentVol);
  }

  void _runDuckRamp() {
    _duckRampTimer?.cancel();
    const duration = Duration(milliseconds: 300);
    final startVol = _currentVol;
    final steps = (duration.inMilliseconds / _rampInterval.inMilliseconds)
        .ceil()
        .clamp(1, 1000);
    var step = 0;
    _duckRampTimer = Timer.periodic(_rampInterval, (timer) async {
      step++;
      final t = (step / steps).clamp(0.0, 1.0);
      // Sample _effectiveVolume() each tick so a duck flip mid-ramp
      // smoothly redirects toward the new target.
      _currentVol = startVol + (_effectiveVolume() - startVol) * t;
      await _current.setVolume(_currentVol);
      if (step >= steps) timer.cancel();
    });
  }
}
