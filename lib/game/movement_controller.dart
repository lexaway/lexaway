import 'package:flame/components.dart';

import 'audio_manager.dart' show Terrain;
import 'components/camera.dart';
import 'events.dart';
import 'lexaway_game.dart';
import 'walk_state.dart';
import 'world/biome_registry.dart';
import 'world/world_map.dart';

/// The walk state machine. Owns only the "is the dino moving, and how far
/// until it stops" logic — animation, scrolling, audio, wind, and dialogue
/// are each handled by their own sibling system subscribed to the events
/// this controller emits.
///
/// Walks stack: answering while already walking extends the journey instead
/// of being ignored.
class MovementController extends Component {
  final WalkState _state = WalkState();

  final Camera _camera;
  final WorldMap _worldMap;
  final GameEvents _events;

  static const double _stepInterval = 0.3;
  static const int _runStreakThreshold = 3;
  static const double _runDistanceMultiplier = 1.5;

  /// Debug mode: dino walks forever without needing correct answers.
  bool debugWalk = false;

  /// Paused walks save their remaining distance and running state here, so
  /// `resume()` can pick up exactly where the dino left off without losing
  /// in-flight progress earned from prior correct answers.
  double _pausedRemaining = 0;
  bool _pausedRunning = false;
  bool _isPaused = false;

  bool get isPaused => _isPaused;
  bool get isWalking => _state.walking;

  MovementController({
    required Camera camera,
    required WorldMap worldMap,
    required GameEvents events,
  })  : _camera = camera,
        _worldMap = worldMap,
        _events = events;

  Terrain get _currentTerrain {
    final biome = _worldMap.biomeAt(_camera.scrollOffset);
    return BiomeRegistry.get(biome).footstepTerrain;
  }

  void correctAnswer({required int streak, required String answer}) {
    final shouldRun = streak >= _runStreakThreshold;
    final distance = shouldRun
        ? LexawayGame.walkTarget * _runDistanceMultiplier
        : LexawayGame.walkTarget;
    if (_isPaused) {
      // Buffer for [resume] — don't walk through the cabinet just because the
      // user kept answering during the encounter.
      _pausedRemaining += distance;
      if (shouldRun) _pausedRunning = true;
      _events.emit(AnswerCorrect(streak, answer));
      return;
    }
    _state.remaining += distance;

    // Upgrade to run mid-walk if streak crosses the threshold.
    final wasAlreadyWalking = _state.walking;
    if (shouldRun && !_state.running) {
      _state.running = true;
      if (wasAlreadyWalking) {
        _events.emit(const WalkSpeedChanged(running: true));
      }
    }

    if (!_state.walking) {
      _state.walking = true;
      _state.stepTimer = _stepInterval; // first step fires immediately
      _events.emit(WalkStarted(running: _state.running));
    }

    _events.emit(AnswerCorrect(streak, answer));
  }

  void wrongAnswer() {
    // Downgrade from run to walk if currently dashing.
    if (_state.running && _state.walking) {
      _state.running = false;
      _events.emit(const WalkSpeedChanged(running: false));
    }
    _events.emit(const AnswerWrong());
  }

  @override
  void update(double dt) {
    if (!_state.walking) return;

    _state.remaining -= _state.currentSpeed * dt;
    _state.stepTimer += dt;
    if (_state.stepTimer >= _stepInterval) {
      _state.stepTimer -= _stepInterval;
      _events.emit(StepTaken(1, terrain: _currentTerrain));
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
      _events.emit(StepTaken(skippedSteps, terrain: _currentTerrain));
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
    _events.emit(WalkStopped(skipDistance: skipDistance));
  }

  /// Halt the walk cleanly for an encounter (claw machine etc.) without
  /// losing accrued distance. Emits [WalkStopped] so audio/animation/scroll
  /// subscribers sync to a stopped state — [resume] later re-emits
  /// [WalkStarted] with the saved running flag, and the saved distance is
  /// restored to `_state.remaining`.
  ///
  /// Idempotent. No-op if not currently walking.
  void pause() {
    if (_isPaused) return;
    if (!_state.walking) {
      // Still mark paused so [resume] is a clean no-op and so further
      // correctAnswer() calls during the encounter accumulate into
      // [_pausedRemaining] rather than restarting the walk mid-encounter.
      _isPaused = true;
      return;
    }
    _pausedRemaining = _state.remaining;
    _pausedRunning = _state.running;
    _isPaused = true;
    _state.walking = false;
    _state.running = false;
    _state.remaining = 0;
    _state.stepTimer = 0;
    _events.emit(const WalkStopped());
  }

  /// Resume after [pause]. Re-emits [WalkStarted] if there's distance to
  /// cover. Safe to call when not paused (no-op).
  void resume() {
    if (!_isPaused) return;
    _isPaused = false;
    if (_pausedRemaining <= 0) return;
    _state.remaining = _pausedRemaining;
    _state.running = _pausedRunning;
    _state.walking = true;
    _state.stepTimer = _stepInterval;
    _pausedRemaining = 0;
    _pausedRunning = false;
    _events.emit(WalkStarted(running: _state.running));
  }

  /// Toggle continuous debug walking. When enabled, the dino walks forward
  /// endlessly without needing correct answers.
  void toggleDebugWalk() {
    debugWalk = !debugWalk;
    if (debugWalk && !_state.walking) {
      _state.remaining = LexawayGame.walkTarget;
      _state.walking = true;
      _state.stepTimer = _stepInterval;
      _events.emit(const WalkStarted(running: false));
    }
  }
}
