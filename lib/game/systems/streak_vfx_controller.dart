import 'dart:async';

import 'package:flame/components.dart';

import '../components/aura_effect.dart';
import '../components/player.dart';
import '../components/spark_burst_effect.dart';
import '../events.dart';
import '../lexaway_game.dart';

/// Spawns one-shot streak rewards on the dino:
///   - streak == 3      → AuraEffect (the "now he's running" power-up flash)
///   - streak % 10 == 0 → SparkBurstEffect (milestone celebration)
///
/// Audio for these tiers is handled by [AudioCueController]; this system
/// owns the visuals only.
class StreakVfxController extends Component with HasGameReference<LexawayGame> {
  final GameEvents _events;
  final Player _player;

  StreamSubscription<AnswerCorrect>? _sub;

  StreakVfxController({
    required GameEvents events,
    required Player player,
  })  : _events = events,
        _player = player;

  @override
  void onMount() {
    super.onMount();
    _sub = _events.on<AnswerCorrect>().listen(_handle);
  }

  Future<void> _handle(AnswerCorrect event) async {
    final streak = event.streak;
    if (streak == 3) {
      final center = _player.position + _player.size / 2;
      final aura = await AuraEffect.create(images: game.images, center: center);
      game.add(aura);
    } else if (streak >= 10 && streak % 10 == 0) {
      // Anchor on the dino's upper torso rather than dead-center so the
      // burst reads around the head/shoulders.
      final origin = _player.position +
          Vector2(_player.size.x / 2, _player.size.y * 0.35);
      final burst = await SparkBurstEffect.create(
        images: game.images,
        origin: origin,
      );
      game.add(burst);
    }
  }

  @override
  void onRemove() {
    _sub?.cancel();
    super.onRemove();
  }
}
