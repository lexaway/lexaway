import 'package:flame/components.dart';

import 'events.dart';
import 'lexaway_game.dart';
import 'walk_state.dart';

/// The walk state machine. Owns only the "is the dino moving, and how far
/// until it stops" logic — animation, scrolling, audio, wind, and dialogue
/// are each handled by their own sibling system subscribed to the events
/// this controller emits.
///
/// Walks stack: answering while already walking extends the journey instead
/// of being ignored.
class MovementController extends Component with HasGameReference<LexawayGame> {
  final WalkState _state = WalkState();

  static const double _stepInterval = 0.3;
  static const int _runStreakThreshold = 3;
  static const double _runDistanceMultiplier = 1.5;

  bool get isWalking => _state.walking;

  void correctAnswer({required int streak, required String answer}) {
    final shouldRun = streak >= _runStreakThreshold;
    final distance = shouldRun
        ? LexawayGame.walkTarget * _runDistanceMultiplier
        : LexawayGame.walkTarget;
    _state.remaining += distance;

    // Upgrade to run mid-walk if streak crosses the threshold.
    final wasAlreadyWalking = _state.walking;
    if (shouldRun && !_state.running) {
      _state.running = true;
      if (wasAlreadyWalking) {
        game.events.emit(const WalkSpeedChanged(running: true));
      }
    }

    if (!_state.walking) {
      _state.walking = true;
      _state.stepTimer = _stepInterval; // first step fires immediately
      game.events.emit(WalkStarted(running: _state.running));
    }

    game.events.emit(AnswerCorrect(streak, answer));
  }

  void wrongAnswer() {
    // Downgrade from run to walk if currently dashing.
    if (_state.running && _state.walking) {
      _state.running = false;
      game.events.emit(const WalkSpeedChanged(running: false));
    }
    game.events.emit(const AnswerWrong());
  }

  @override
  void update(double dt) {
    if (!_state.walking) return;

    _state.remaining -= _state.currentSpeed * dt;
    _state.stepTimer += dt;
    if (_state.stepTimer >= _stepInterval) {
      _state.stepTimer -= _stepInterval;
      game.events.emit(const StepTaken(1));
    }
    if (_state.remaining <= 0) {
      _state.remaining = 0;
      _stop();
    }
  }

  /// Finish any in-progress walk immediately (no animation).
  void finishMovement() {
    if (!_state.walking) return;
    final skipDistance = _state.remaining;
    final skippedSteps =
        (skipDistance / (_state.currentSpeed * _stepInterval)).ceil();
    if (skippedSteps > 0) game.events.emit(StepTaken(skippedSteps));
    _state.remaining = 0;
    _stop(skipDistance: skipDistance);
  }

  void _stop({double skipDistance = 0}) {
    _state.walking = false;
    _state.running = false;
    _state.stepTimer = 0;
    game.events.emit(WalkStopped(skipDistance: skipDistance));
  }
}
