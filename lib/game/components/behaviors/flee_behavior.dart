import '../../audio_manager.dart';
import '../../lexaway_game.dart';
import '../creature.dart';
import 'creature_behavior_component.dart';

/// Flees when the player gets within [triggerTiles] tiles. Direction is
/// chosen randomly per-creature (seeded via the parent's RNG) so bunnies
/// scatter both forward and backward instead of all bolting the same way.
class FleeBehavior extends CreatureBehaviorComponent {
  final double speed;
  final double triggerTiles;

  late final double _triggerPx;
  bool _activated = false;
  double _direction = -1; // -1 = leftward (default), +1 = rightward

  @override
  bool get isExclusive => _activated;

  FleeBehavior({required this.speed, required this.triggerTiles});

  @override
  void onMount() {
    super.onMount();
    _triggerPx = triggerTiles * 16 * LexawayGame.pixelScale;
  }

  @override
  void update(double dt) {
    if (_activated) {
      parent.moveWorldX(_direction * speed * dt);
      return;
    }

    final game = parent.game;
    final scrollOffset = game.scrollOffset;
    final playerScreenX = game.size.x * 0.25;
    final myScreenX = parent.worldX - scrollOffset;
    final gap = myScreenX - playerScreenX;

    if (gap > 0 && gap < _triggerPx) {
      _activate();
    }
  }

  void _activate() {
    _activated = true;
    // Grass-rustle one-shot as the critter bolts (not per hop).
    AudioManager.instance.playCreatureFlee();
    _direction = parent.rng.nextBool() ? 1.0 : -1.0;
    // Sprite faces right by default. When fleeing left we flip horizontally,
    // which negates scale.x and shifts rendering by the sprite width — so
    // compensate by nudging worldX so the creature doesn't visually teleport.
    if (_direction < 0) {
      parent.moveWorldX(parent.size.x);
      parent.setFlip(true);
    }
    _loopHop();
  }

  void _loopHop() {
    parent.playAnim(CreatureAnim.hop, onComplete: () {
      if (_activated && parent.isMounted) _loopHop();
    });
  }
}
