import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Crossfading background music player.
///
/// Owns two [AudioPlayer] instances that swap roles per track change to
/// fade out the old track while the new one fades in. Volume is [setVolume]
/// (user slider) times the [setDucking] multiplier (TTS overlay).
///
/// Tracks are keyed by an opaque [identifier] (stable across catalog rebuilds,
/// used for position caching and completion events) plus a [Source] (what
/// audioplayers plays). The split lets assets and downloaded files share one
/// pipeline.
class BgmService {
  static const double _duckMultiplier = 0.3;
  static const Duration _rampInterval = Duration(milliseconds: 50);

  AudioPlayer _current = AudioPlayer();
  AudioPlayer _previous = AudioPlayer();

  String? _currentId;
  Source? _currentSource;
  bool _currentLoop = true;
  double _userVolume = 1.0;
  bool _ducking = false;
  bool _paused = false;

  double _currentVol = 0;
  double _previousVol = 0;

  /// Last playback position per track id, captured on crossfade-away so users
  /// can hop to Settings and back without losing their place. FIFO-capped at
  /// [_positionsCap]; uninstalled-pack ids dropped via
  /// [forgetPositionsWithPrefix].
  static const int _positionsCap = 128;
  final Map<String, Duration> _positions = {};

  /// Serializes [playLoop] and [stop]. Without it, an in-flight stop() racing a
  /// follow-up playLoop() (same AudioPlayer instances) can leave the new player
  /// muted/stuck.
  Future<void>? _transitionLock;

  /// True while an unmute kick's [playLoop] is in flight. Suppresses redundant
  /// kicks during mute/unmute thrash — the in-flight playLoop reads the latest
  /// [_userVolume] when it dequeues.
  bool _unmutePending = false;

  int _transitionId = 0;
  Timer? _rampTimer;
  Timer? _duckRampTimer;

  /// Fires a non-looping track's identifier at its natural end, so the
  /// scheduler advances at song boundaries rather than on a timer.
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

  /// Crossfade to the track keyed by [identifier], played from [source].
  /// No-op if it's already the active id. If the id has been played before,
  /// resumes from the saved position.
  ///
  /// When [loop] is false, the track plays once through and emits on
  /// [onTrackComplete] when finished — letting callers chain to a follow-up
  /// track only at the natural end. Defaults to true for menu loops.
  Future<void> playLoop(
    String identifier,
    Source source, {
    Duration crossfade = const Duration(milliseconds: 1500),
    bool loop = true,
  }) async {
    final prev = _transitionLock;
    final completer = Completer<void>();
    _transitionLock = completer.future;

    try {
      await prev;
      if (identifier == _currentId) return;

      final outgoingId = _currentId;
      if (outgoingId != null) {
        final pos = await _current.getCurrentPosition();
        if (pos != null) _rememberPosition(outgoingId, pos);
      }

      _currentId = identifier;
      _currentSource = source;
      _currentLoop = loop;
      // _paused: app backgrounded — resume() will start it.
      // _userVolume == 0: user opted out of music — setVolume() will start it.
      if (_paused || _userVolume == 0) return;

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

      // Pause/mute may have flipped across the awaits above; bail before
      // committing. resume()/setVolume() will redo this leg.
      if (_paused || _userVolume == 0) return;

      // audioplayers' _completePrepared can hang ~30s on iOS when the platform
      // "prepared" event never fires. Our own 5s timeout, then discard the
      // stuck player and retry once with a fresh instance.
      if (!await _tryPlay(_current, source)) {
        final stuck = _current;
        unawaited(() async {
          // stop() first so a late prepared event can't emit audio between
          // play() resolving and dispose() landing.
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
        // Pause/mute may have flipped; bail. resume()/setVolume() redoes it.
        if (_paused || _userVolume == 0) return;
        await _tryPlay(_current, source);
      }

      final savedPos = _positions[identifier];
      if (savedPos != null) {
        try {
          await _current
              .seek(savedPos)
              .timeout(const Duration(seconds: 2));
        } catch (_) {
          // Seek didn't complete in time; live with starting at 0.
        }
      }

      // Re-attach completion listener to the current player (post-swap/recovery).
      // Looping tracks never fire onPlayerComplete, so only subscribe for one-shots.
      _completeSub?.cancel();
      _completeSub = null;
      if (!loop) {
        final completedId = identifier;
        _completeSub = _current.onPlayerComplete.listen((_) {
          if (_currentId == completedId) {
            _completeCtrl.add(completedId);
          }
        });
      }

      _runRamp(id: id, duration: crossfade);
    } finally {
      completer.complete();
      if (_transitionLock == completer.future) _transitionLock = null;
    }
  }

  /// User-facing volume (0..1), live from the slider. Dropping to zero pauses
  /// playback (no decoding silent audio); rising off zero kicks the deferred
  /// track back into play.
  void setVolume(double v) {
    final newVol = v.clamp(0.0, 1.0);
    final wasZero = _userVolume == 0;
    final isZero = newVol == 0;
    _userVolume = newVol;
    if (isZero && !wasZero) {
      _rampTimer?.cancel();
      _duckRampTimer?.cancel();
      _currentVol = 0;
      _previousVol = 0;
      if (_currentId != null) {
        unawaited(_current.pause());
        unawaited(_previous.pause());
      }
      return;
    }
    if (!isZero && wasZero) {
      final id = _currentId;
      final source = _currentSource;
      if (id != null && source != null && !_paused && !_unmutePending) {
        // Coalesce against slider thrash: one kick picks up the latest
        // _userVolume on dequeue, so extra mute→unmute cycles needn't stack.
        _unmutePending = true;
        final wasLoop = _currentLoop;
        _currentId = null; // force playLoop's same-id guard to relent
        unawaited(() async {
          try {
            await playLoop(id, source, loop: wasLoop);
          } finally {
            _unmutePending = false;
          }
        }());
      }
      return;
    }
    _pushVolumeIfIdle();
  }

  /// Toggle the TTS-driven duck. Down is instant (a ramp would lag a short
  /// utterance); up eases over ~300ms so music doesn't pop back at full volume.
  void setDucking(bool ducking) {
    if (_ducking == ducking) return;
    _ducking = ducking;
    if (_currentId == null || _paused || _userVolume == 0) return;
    if (_rampTimer != null && _rampTimer!.isActive) return;
    if (ducking) {
      _duckRampTimer?.cancel();
      _currentVol = _effectiveVolume();
      _current.setVolume(_currentVol);
    } else {
      _runDuckRamp();
    }
  }

  /// Stop and clear the active track. Unlike [pause], forgets what was playing
  /// so [resume] won't restart it — used to make gameplay silent.
  Future<void> stop() async {
    final prev = _transitionLock;
    final completer = Completer<void>();
    _transitionLock = completer.future;
    try {
      await prev;
      _rampTimer?.cancel();
      _duckRampTimer?.cancel();
      await _completeSub?.cancel();
      _completeSub = null;
      _currentId = null;
      _currentSource = null;
      _currentVol = 0;
      _previousVol = 0;
      await _current.stop();
      await _previous.stop();
    } finally {
      completer.complete();
      if (_transitionLock == completer.future) _transitionLock = null;
    }
  }

  /// Drop saved positions for track ids starting with [prefix] (pack
  /// uninstalled), so a reinstall doesn't seek into a stale position.
  void forgetPositionsWithPrefix(String prefix) {
    _positions.removeWhere((id, _) => id.startsWith(prefix));
  }

  void _rememberPosition(String id, Duration pos) {
    _positions.remove(id);
    _positions[id] = pos;
    while (_positions.length > _positionsCap) {
      _positions.remove(_positions.keys.first);
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

  /// Resume the active track, or start the deferred play if [playLoop] ran
  /// while paused. A pause mid-crossfade won't resume the outgoing track — it
  /// stays silent and is cleaned up on the next [playLoop].
  Future<void> resume() async {
    if (!_paused) return;
    _paused = false;
    final id = _currentId;
    final source = _currentSource;
    if (id == null || source == null) return;
    if (_userVolume == 0) return; // setVolume() will start it on unmute

    if (_currentVol == 0 && _previousVol == 0) {
      // Never started — playLoop deferred during pause.
      final wasLoop = _currentLoop;
      _currentId = null; // force playLoop to do its thing
      await playLoop(id, source, loop: wasLoop);
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

  Future<bool> _tryPlay(AudioPlayer player, Source source) async {
    try {
      await player.play(source).timeout(const Duration(seconds: 5));
      return true;
    } on TimeoutException {
      return false;
    } catch (e, s) {
      debugPrint('[BgmService] play failed: $e\n$s');
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
    if (_currentId == null || _paused) return;
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
