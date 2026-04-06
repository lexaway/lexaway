import 'package:flame/components.dart';

import 'audio_manager.dart';
import 'components/speech_messages.dart' show SpeechMessages;
import 'lexaway_game.dart';

/// Manages the walk-one-tile state machine: animation, scrolling,
/// parallax, footstep audio, and idle chatter timeout.
class WalkController extends Component with HasGameReference<LexawayGame> {
  bool _isWalking = false;
  double _walkProgress = 0;
  double _stepTimer = 0;
  double _idleTimer = 0;

  static const double _stepInterval = 0.3;
  static const double _idleTimeout = 60.0;

  bool get isWalking => _isWalking;

  void correctAnswer({required int streak, required String answer}) {
    if (_isWalking) return;
    _isWalking = true;
    _walkProgress = 0;
    _idleTimer = 0;
    _stepTimer = _stepInterval; // first step fires immediately

    game.player.walk();
    game.parallaxComponent.parallax!.baseVelocity = Vector2(
      LexawayGame.walkSpeed * 0.1,
      0,
    );
    game.ground.startScrolling(LexawayGame.walkSpeed);

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
    AudioManager.instance.playWrong();
    final msg = SpeechMessages.pickWrongMessage(locale: game.locale);
    if (msg != null) game.speechBubble.show(msg);
  }

  @override
  void update(double dt) {
    if (_isWalking) {
      _walkProgress += LexawayGame.walkSpeed * dt;
      _stepTimer += dt;
      if (_stepTimer >= _stepInterval) {
        _stepTimer -= _stepInterval;
        AudioManager.instance.playFootstep();
      }
      if (_walkProgress >= LexawayGame.walkTarget) {
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
  }

  /// Finish any in-progress walk immediately (no animation).
  void finishWalk() {
    if (!_isWalking) return;
    // Advance ground to where the walk would have ended
    final remaining = LexawayGame.walkTarget - _walkProgress;
    if (remaining > 0) {
      game.ground.scrollOffset += remaining;
    }
    _stop();
  }

  void _stop() {
    _isWalking = false;
    _stepTimer = 0;
    game.player.idle();
    game.parallaxComponent.parallax!.baseVelocity = Vector2.zero();
    game.ground.stopScrolling();
    game.saveWorldState();
  }
}
