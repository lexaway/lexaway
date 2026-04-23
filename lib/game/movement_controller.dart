import 'package:flame/components.dart';

import 'audio_manager.dart' show Terrain;
import 'events.dart';
import 'lexaway_game.dart';
import 'walk_state.dart';
import 'world/biome_registry.dart';

/// The walk state machine. Owns only the "is the dino moving, and how far
/// until it stops" logic — animation, scrolling, audio, wind, and dialogue
/// are each handled by their own sibling system subscribed to the events
/// this controller emits.
///
/// Walks stack: answering while already walking extends the journey instead
/// of being ignored.
class MovementController extends Component with HasGameReference<LexawayGame> {
  final WalkState _state = WalkState();

  // Feeds daily-goal session-length labels; see `dailyGoalPresets` in
  // `lib/providers/daily_goal.dart` if you change this.
  static const double _stepInterval = 0.3;
  static const int _runStreakThreshold = 3;
  static const double _runDistanceMultiplier = 1.5;

  /// Debug mode: dino walks forever without needing correct answers.
  bool debugWalk = false;

  bool get isWalking => _state.walking;

  Terrain get _currentTerrain {
    final biome = game.worldMap.biomeAt(game.ground.scrollOffset);
    return BiomeRegistry.get(biome).footstepTerrain;
  }

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
      game.events.emit(StepTaken(1, terrain: _currentTerrain));
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
    if (skippedSteps > 0) {
      game.events.emit(StepTaken(skippedSteps, terrain: _currentTerrain));
    }
    _state.remaining = 0;
    _stop(skipDistance: skipDistance);
  }

  void _stop({double skipDistance = 0}) {
    if (debugWalk) {
      // Keep walking forever — top up the distance instead of stopping.
      _state.remaining += LexawayGame.walkTarget;
      return;
    }
    _state.walking = false;
    _state.running = false;
    _state.stepTimer = 0;
    game.events.emit(WalkStopped(skipDistance: skipDistance));
  }

  /// Toggle continuous debug walking. When enabled, the dino walks forward
  /// endlessly without needing correct answers.
  void toggleDebugWalk() {
    debugWalk = !debugWalk;
    if (debugWalk && !_state.walking) {
      _state.remaining = LexawayGame.walkTarget;
      _state.walking = true;
      _state.stepTimer = _stepInterval;
      game.events.emit(const WalkStarted(running: false));
    }
  }
}
