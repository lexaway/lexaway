import 'dart:async';

import 'package:flame/components.dart';

import '../audio_manager.dart';
import '../components/coin.dart' show CoinType;
import '../events.dart';

/// Listens to gameplay events and plays the matching SFX.
///
/// Pure event consumer — no `game.*` reach-through, no `update()`.
/// `AudioManager` is a singleton so this system doesn't even need a
/// reference to it, just the events stream.
class AudioCueController extends Component {
  StreamSubscription<GameEvent>? _sub;
  final GameEvents _events;

  AudioCueController({required GameEvents events}) : _events = events;

  @override
  void onMount() {
    super.onMount();
    _sub = _events.on<GameEvent>().listen(_handle);
  }

  void _handle(GameEvent event) {
    final audio = AudioManager.instance;
    switch (event) {
      case AnswerCorrect(:final streak):
        if (streak == 3) {
          audio.playPowerUp();
        } else if (streak >= 10 && streak % 10 == 0) {
          audio.playMilestone();
        } else if (streak == 5 || streak == 25) {
          audio.playStreak();
        } else {
          audio.playCorrect();
        }
      case AnswerWrong():
        audio.playWrong();
      case StepTaken(:final terrain):
        // One chirp per step event regardless of count — matches the
        // previous behavior where `finishMovement` skipped ahead without
        // spamming footstep sounds in the same frame.
        audio.playFootstep(terrain: terrain);
      case CoinCollected(:final type):
        if (type == CoinType.diamond) {
          audio.playGem();
        } else {
          audio.playCoin();
        }
      default:
        break;
    }
  }

  @override
  void onRemove() {
    _sub?.cancel();
    super.onRemove();
  }
}
