import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../claw_machine/cabinet.dart';
import '../claw_machine/claw_session.dart';
import '../events.dart';
import '../lexaway_game.dart';
import '../world/scrolling_item_layer.dart';
import 'player.dart';

/// World-side claw machine cabinet. Static, scrolls with the world like any
/// other [ScrollingWorldItem]; emits [ClawMachineEntered] when the dino
/// bumps into it. Uses a `_triggered` latch so the event fires exactly once
/// per encounter — the manager culls the machine when the screen flow marks
/// it complete.
///
/// Idle state: just an [ExteriorComponent] child. During an encounter,
/// [startSession] mounts a [ClawSessionComponent] (which adds its play
/// subcomponents as siblings here, using priorities to interleave with
/// the exterior); [endSession] tears the whole subtree down again.
class ClawMachine extends PositionComponent
    with
        HasGameReference<LexawayGame>,
        CollisionCallbacks,
        ScrollingWorldItem {
  @override
  double worldX;

  @override
  final int itemIndex;

  bool _triggered = false;
  ClawSessionComponent? _session;

  ClawMachine({required this.worldX, required this.itemIndex})
      : super(size: Vector2(ClawCabinet.cabW, ClawCabinet.cabH));

  @override
  double get layerWidth => size.x;

  ClawSessionComponent? get session => _session;

  @override
  Future<void> onLoad() async {
    final groundTop = game.size.y * LexawayGame.groundLevel;
    position.y = groundTop - size.y;

    add(ExteriorComponent());
    add(RectangleHitbox());
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (_triggered || other is! Player) return;
    _triggered = true;
    game.events.emit(
      ClawMachineEntered(itemIndex: itemIndex, worldX: worldX),
    );
  }

  /// Mount a session and its play subtree. Idempotent — if a session is
  /// already running this is a no-op.
  void startSession({required ClawAttemptCallback onResultReady}) {
    if (_session != null) return;
    final session = ClawSessionComponent(onResultReady: onResultReady);
    _session = session;
    add(session);
  }

  /// Tear down the session. The session's own `onRemove` cleans up the
  /// sibling play components it added during onLoad.
  void endSession() {
    final s = _session;
    if (s == null) return;
    _session = null;
    s.removeFromParent();
  }
}
