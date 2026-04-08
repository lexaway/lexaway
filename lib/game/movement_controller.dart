import 'dart:math';

import 'package:flame/components.dart';

import 'audio_manager.dart';
import 'components/player.dart' show DinoAnim;
import 'components/speech_messages.dart' show SpeechMessages;
import 'lexaway_game.dart';

/// Manages the walk state machine: animation, scrolling,
/// parallax, footstep audio, step counting, and idle chatter.
///
/// Walks now stack — answering while already walking extends the
/// journey instead of being ignored.
class MovementController extends Component with HasGameReference<LexawayGame> {
  double _walkRemaining = 0;
  bool _isWalking = false;
  bool _isRunning = false;
  double _stepTimer = 0;
  double _idleTimer = 0;
  double _fidgetTimer = 0;
  double _nextFidgetAt = _rollFidgetDelay();

  static const double _stepInterval = 0.3;
  static const double _idleTimeout = 60.0;
  static const int _runStreakThreshold = 3;
  static const double _runSpeedMultiplier = 1.8;
  static const double _runDistanceMultiplier = 1.5;
  // Random fidget every 8–20 seconds while idle
  static const double _fidgetMin = 8.0;
  static const double _fidgetMax = 20.0;
  static final _rng = Random();

  static double _rollFidgetDelay() =>
      _fidgetMin + _rng.nextDouble() * (_fidgetMax - _fidgetMin);

  bool get isWalking => _isWalking;

  Function(int steps)? onStepTaken;

  void correctAnswer({required int streak, required String answer}) {
    final shouldRun = streak >= _runStreakThreshold;
    final distance = shouldRun
        ? LexawayGame.walkTarget * _runDistanceMultiplier
        : LexawayGame.walkTarget;
    _walkRemaining += distance;
    _idleTimer = 0;
    _fidgetTimer = 0;

    // Upgrade to run mid-walk if streak crosses the threshold
    if (shouldRun && !_isRunning) {
      _isRunning = true;
      game.player.run();
      game.windLines.start();
      final speed = LexawayGame.walkSpeed * _runSpeedMultiplier;
      game.parallaxComponent.parallax!.baseVelocity =
          Vector2(speed * 0.1, 0);
      game.ground.startScrolling(speed);
    }

    if (!_isWalking) {
      _isWalking = true;
      _stepTimer = _stepInterval; // first step fires immediately
      if (!_isRunning) {
        game.player.walk();
        game.parallaxComponent.parallax!.baseVelocity =
            Vector2(LexawayGame.walkSpeed * 0.1, 0);
        game.ground.startScrolling(LexawayGame.walkSpeed);
      }
    }

    if (streak == 5 || streak == 10 || streak == 25) {
      AudioManager.instance.playStreak();
    } else {
      AudioManager.instance.playCorrect();
    }

    final msg = SpeechMessages.pickCorrectMessage(
      streak,
      answer,
      locale: game.locale,
    );
    if (msg != null) game.speechBubble.show(msg);
  }

  void wrongAnswer() {
    _idleTimer = 0;
    _fidgetTimer = 0;

    // Downgrade from run to walk if currently dashing
    if (_isRunning && _isWalking) {
      _isRunning = false;
      game.player.walk();
      game.windLines.stop();
      game.parallaxComponent.parallax!.baseVelocity =
          Vector2(LexawayGame.walkSpeed * 0.1, 0);
      game.ground.startScrolling(LexawayGame.walkSpeed);
    }

    AudioManager.instance.playWrong();
    final msg = SpeechMessages.pickWrongMessage(locale: game.locale);
    if (msg != null) game.speechBubble.show(msg);
  }

  @override
  void update(double dt) {
    if (_isWalking) {
      final speed = _isRunning
          ? LexawayGame.walkSpeed * _runSpeedMultiplier
          : LexawayGame.walkSpeed;
      _walkRemaining -= speed * dt;
      _stepTimer += dt;
      if (_stepTimer >= _stepInterval) {
        _stepTimer -= _stepInterval;
        AudioManager.instance.playFootstep();
        onStepTaken?.call(1);
      }
      if (_walkRemaining <= 0) {
        _walkRemaining = 0;
        _stop();
      }
    }

    // Idle chatter (clamp dt to prevent spam after backgrounding)
    _idleTimer += dt.clamp(0, 1);
    if (_idleTimer >= _idleTimeout) {
      _idleTimer = 0;
      game.speechBubble.show(
        SpeechMessages.pickIdleMessage(locale: game.locale),
      );
    }

    // Random fidgets while standing still
    if (!_isWalking && !game.player.isBusy) {
      _fidgetTimer += dt.clamp(0, 1);
      if (_fidgetTimer >= _nextFidgetAt) {
        _fidgetTimer = 0;
        _nextFidgetAt = _rollFidgetDelay();
        game.player.play(DinoAnim.jump);
      }
    }
  }

  /// Finish any in-progress walk immediately (no animation).
  void finishMovement() {
    if (!_isWalking) return;
    game.ground.scrollOffset += _walkRemaining;
    final speed = _isRunning
        ? LexawayGame.walkSpeed * _runSpeedMultiplier
        : LexawayGame.walkSpeed;
    // Count the steps we're skipping
    final skippedSteps =
        (_walkRemaining / (speed * _stepInterval)).ceil();
    if (skippedSteps > 0) onStepTaken?.call(skippedSteps);
    _walkRemaining = 0;
    _stop();
  }

  void _stop() {
    _isWalking = false;
    _isRunning = false;
    _stepTimer = 0;
    _fidgetTimer = 0;
    _nextFidgetAt = _rollFidgetDelay();
    game.player.idle();
    game.windLines.stop();
    game.parallaxComponent.parallax!.baseVelocity = Vector2.zero();
    game.ground.stopScrolling();
    game.saveWorldState();
  }
}
