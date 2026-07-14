import '../../lexaway_game.dart';
import 'creature_behavior_component.dart';

/// Pins the creature's feet to the ground line. Runs in [onLoad] (awaited
/// by [Creature.onLoad]) so `position.y` is correct on the first frame.
///
/// [footPadding] (transparent source pixels below the feet) is scaled and
/// subtracted so the visible feet sit on the ground rather than hovering.
class GroundAnchorBehavior extends CreatureBehaviorComponent {
  final double footPadding;

  GroundAnchorBehavior({this.footPadding = 0});

  @override
  Future<void> onLoad() async {
    final groundTop = parent.game.size.y * LexawayGame.groundLevel;
    final padPx = footPadding * parent.spriteScale;
    parent.position.y = groundTop - parent.size.y + padPx;
  }
}
