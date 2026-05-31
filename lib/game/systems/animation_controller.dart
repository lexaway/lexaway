import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';

import '../audio_manager.dart';
import '../components/player.dart';
import '../events.dart';

/// Owns the dino's on-screen "personality": routing walk/run/idle animations,
/// scheduling random fidget jumps while standing still, and firing idle
/// chatter after a minute of silence.
class AnimationController extends Component {
  static const double _idleTimeout = 60.0;
  static const double _fidgetMin = 8.0;
  static const double _fidgetMax = 20.0;
  static final _rng = Random();

  static double _rollFidgetDelay() =>
      _fidgetMin + _rng.nextDouble() * (_fidgetMax - _fidgetMin);

  StreamSubscription<GameEvent>? _sub;
  final Player _player;
  final GameEvents _events;

  bool _walking = false;
  double _idleTimer = 0;
  double _fidgetTimer = 0;
  double _nextFidgetAt = _rollFidgetDelay();

  AnimationController({required Player player, required GameEvents events})
      : _player = player,
        _events = events;

  @override
  void onMount() {
    super.onMount();
    _sub = _events.on<GameEvent>().listen(_handle);
  }

  void _handle(GameEvent event) {
    switch (event) {
      case WalkStarted(:final running):
        _walking = true;
        _resetIdle();
        if (running) {
          _player.run();
        } else {
          _player.walk();
        }
      case WalkSpeedChanged(:final running):
        if (running) {
          _player.run();
        } else {
          _player.walk();
        }
      case WalkStopped():
        _walking = false;
        _player.idle();
      case AnswerCorrect():
      case AnswerWrong():
        _resetIdle();
      default:
        break;
    }
  }

  void _resetIdle() {
    _idleTimer = 0;
    _fidgetTimer = 0;
  }

  @override
  void update(double dt) {
    // Clamp dt so backgrounding the app doesn't instantly drain timers.
    final clamped = dt.clamp(0, 1);

    // Idle chatter — fires once per timeout window; DialogueController
    // handles picking and showing the actual message.
    _idleTimer += clamped;
    if (_idleTimer >= _idleTimeout) {
      _idleTimer = 0;
      _events.emit(const IdleChatterTriggered());
    }

    // Random fidget jumps while standing still and not mid-one-shot.
    if (!_walking && !_player.isBusy) {
      _fidgetTimer += clamped;
      if (_fidgetTimer >= _nextFidgetAt) {
        _fidgetTimer = 0;
        _nextFidgetAt = _rollFidgetDelay();
        _player.play(DinoAnim.jump);
        AudioManager.instance.playFidgetHop();
      }
    }
  }

  @override
  void onRemove() {
    _sub?.cancel();
    super.onRemove();
  }
}
