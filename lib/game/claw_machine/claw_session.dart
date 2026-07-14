import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import '../../data/collectibles/collectible.dart';
import '../../data/collectibles/registry.dart';
import '../audio_manager.dart';
import '../components/claw_machine.dart';
import 'action_button.dart';
import 'cabinet.dart';
import 'claw.dart';
import 'joystick.dart';
import 'prize_door.dart';
import 'prize_sphere.dart';
import 'sphere.dart';

/// Phases of a single attempt.
enum ClawPhase { aiming, dropping, grabbing, retracting, delivering, result }

/// Surface only the gameplay outcome; the screen layers `coinsSpent`
/// onto the public [ClawMachineCompleted] event. [prize] is the
/// collectible the player walked away with, or null on a miss.
typedef ClawAttemptCallback = void Function({
  required bool won,
  required int spheresWon,
  Collectible? prize,
});

/// Logic holder for a single in-world claw encounter. Mounted as a child
/// of the [ClawMachine] cabinet; its play subcomponents are added as
/// siblings so priorities can interleave them with the exterior sprite.
///
/// Renders nothing itself. Drives clawX/Y/closed, sphere physics, and the
/// drop-grab-retract-deliver sequence.
class ClawSessionComponent extends PositionComponent {
  // 0.8 px per ~16 ms tick ≈ 50 px/s.
  static const double stickSpeedPerSec = 50.0;

  // Physics tuning. Cabinet is 80×128 px so values are small — gravity
  // pulls a sphere across the floor in ~0.6 s.
  static const double gravityPerSec2 = 220.0;
  static const double wallRestitution = 0.35;
  static const double ballRestitution = 0.55;
  static const double groundFriction = 6.0;
  static const double restSpeed = 1.5;
  static const double armHalfWidth = 3.0;

  // Sphere clack SFX: only fire on inbound impacts above this speed, and no
  // more than once per interval so a frame's worth of overlaps stays a single
  // clink instead of a buzz.
  static const double _clinkSpeed = 14.0;
  static const double _clinkInterval = 0.08;
  double _clinkCooldown = 0;

  final ClawAttemptCallback onResultReady;
  ClawSessionComponent({required this.onResultReady}) : super(priority: 0);

  // Public state — sibling components read these every frame and self-position.
  ClawPhase phase = ClawPhase.aiming;
  double clawX = ClawCabinet.glassCenterX;
  double clawY = ClawCabinet.clawRestY;
  bool clawClosed = false;
  bool doorOpen = false;
  int stickDir = 0;
  SphereComponent? capturedSphere;

  bool _won = false;
  int _spheresWon = 0;
  Collectible? _wonPrize;
  bool _resultDispatched = false;

  final List<SphereComponent> _floorSpheres = [];
  final List<Component> _ownedSiblings = [];

  _Anim? _xAnim;
  _Anim? _yAnim;
  // Drives the captured-sphere "fall into the chute" tween. Its target is
  // [_droppedSphere], a separate field from [capturedSphere] so the
  // snap-to-claw assignment in update() doesn't fight the tween.
  _Anim? _dropAnim;
  SphereComponent? _droppedSphere;

  ClawMachine get _cabinet => parent! as ClawMachine;

  @override
  Future<void> onLoad() async {
    final cabinet = _cabinet;

    // Five flag spheres dropped from a few px above the floor with a tiny
    // random velocity for an opening jostle. Loadout re-rolled each session
    // so try-again sees a fresh set.
    final rng = math.Random();
    final loadout = CollectibleRegistry.instance
        .randomFromCategory(cabinet.categoryId, 5, rng: rng);
    // Preload sprites so each sphere's first render has a decoded bitmap —
    // otherwise the first frames show a shell-only ball.
    for (final c in loadout) {
      await CollectibleRegistry.instance.loadSprite(c.spriteAsset);
    }
    final spacing =
        (ClawCabinet.glassRight - ClawCabinet.glassLeft) / (loadout.length + 1);
    for (var i = 0; i < loadout.length; i++) {
      final item = loadout[i];
      final pair = randomShellPair(rng);
      final pos = Vector2(
        ClawCabinet.glassLeft +
            spacing * (i + 1) +
            (rng.nextDouble() - 0.5) * 6,
        ClawCabinet.glassFloorY - 30 + rng.nextDouble() * 8,
      );
      final s = PrizeSphereComponent(
        collectible: item,
        shellLeft: pair.$1,
        shellRight: pair.$2,
        position: pos,
      );
      s.velocity.x = (rng.nextDouble() - 0.5) * 20;
      _floorSpheres.add(s);
      _addSibling(cabinet, s);
    }

    _addSibling(cabinet, CableComponent(session: this));
    _addSibling(cabinet, ClawArmComponent(session: this, isLeft: true));
    _addSibling(cabinet, ClawArmComponent(session: this, isLeft: false));
    _addSibling(cabinet, ClawHeadComponent(session: this));
    _addSibling(cabinet, GlassShineComponent());
    _addSibling(cabinet, PrizeDoorComponent(session: this));
    _addSibling(cabinet, ConsoleStarComponent());
    _addSibling(cabinet, ClawJoystickComponent(session: this));
    _addSibling(cabinet, ActionButtonComponent(session: this));
  }

  void _addSibling(ClawMachine cabinet, Component c) {
    cabinet.add(c);
    _ownedSiblings.add(c);
  }

  @override
  void onRemove() {
    for (final c in _ownedSiblings) {
      c.removeFromParent();
    }
    _ownedSiblings.clear();
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);

    _xAnim = _xAnim?.tick(dt, (v) => clawX = v);
    _yAnim = _yAnim?.tick(dt, (v) => clawY = v);
    if (_droppedSphere != null) {
      _dropAnim =
          _dropAnim?.tick(dt, (v) => _droppedSphere!.position.y = v);
    }

    if (phase == ClawPhase.aiming && stickDir != 0) {
      clawX = (clawX + stickDir * stickSpeedPerSec * dt)
          .clamp(ClawCabinet.clawMinX, ClawCabinet.clawMaxX);
    }

    _stepPhysics(dt);

    if (capturedSphere != null) {
      capturedSphere!.position = Vector2(
        clawX,
        clawY +
            (ClawCabinet.headH - ClawCabinet.armOverlap) +
            ClawCabinet.armH -
            14 +
            5,
      );
    }
  }

  // ─── Physics ────────────────────────────────────────────────────────

  /// Integrate gravity, resolve sphere-sphere overlap, clamp to glass walls,
  /// and let the claw arms shove spheres aside. O(n²) throughout — fine at
  /// five spheres.
  void _stepPhysics(double dt) {
    if (_floorSpheres.isEmpty) return;
    if (_clinkCooldown > 0) _clinkCooldown -= dt;
    const r = SphereComponent.physicsRadius;

    for (final s in _floorSpheres) {
      s.velocity.y += gravityPerSec2 * dt;
      s.position.x += s.velocity.x * dt;
      s.position.y += s.velocity.y * dt;
    }

    for (var i = 0; i < _floorSpheres.length; i++) {
      for (var j = i + 1; j < _floorSpheres.length; j++) {
        _resolveBallBall(_floorSpheres[i], _floorSpheres[j]);
      }
    }

    _resolveClawArms();

    for (final s in _floorSpheres) {
      if (s.position.x < ClawCabinet.glassLeft + r) {
        s.position.x = ClawCabinet.glassLeft + r;
        if (s.velocity.x < 0) s.velocity.x = -s.velocity.x * wallRestitution;
      } else if (s.position.x > ClawCabinet.glassRight - r) {
        s.position.x = ClawCabinet.glassRight - r;
        if (s.velocity.x > 0) s.velocity.x = -s.velocity.x * wallRestitution;
      }
      if (s.position.y > ClawCabinet.glassFloorY - r) {
        s.position.y = ClawCabinet.glassFloorY - r;
        if (s.velocity.y > 0) {
          s.velocity.y = s.velocity.y.abs() < restSpeed
              ? 0
              : -s.velocity.y * wallRestitution;
        }
        // Friction on the floor — exponential decay toward zero.
        s.velocity.x -= s.velocity.x * (1 - math.exp(-groundFriction * dt));
        if (s.velocity.x.abs() < 0.5) s.velocity.x = 0;
      } else if (s.position.y < ClawCabinet.glassTop + r) {
        s.position.y = ClawCabinet.glassTop + r;
        if (s.velocity.y < 0) s.velocity.y = -s.velocity.y * wallRestitution;
      }
    }
  }

  void _resolveBallBall(SphereComponent a, SphereComponent b) {
    var dx = b.position.x - a.position.x;
    var dy = b.position.y - a.position.y;
    const minDist = SphereComponent.physicsRadius * 2;
    var distSq = dx * dx + dy * dy;
    if (distSq >= minDist * minDist) return;
    if (distSq < 0.0001) {
      // Coincident centers — nudge along x so the next frame can resolve.
      dx = 0.01;
      dy = 0;
      distSq = 0.0001;
    }
    final dist = math.sqrt(distSq);
    final nx = dx / dist;
    final ny = dy / dist;
    final overlap = minDist - dist;

    a.position.x -= nx * overlap * 0.5;
    a.position.y -= ny * overlap * 0.5;
    b.position.x += nx * overlap * 0.5;
    b.position.y += ny * overlap * 0.5;

    final relVel =
        (b.velocity.x - a.velocity.x) * nx + (b.velocity.y - a.velocity.y) * ny;
    if (relVel >= 0) return;
    // Throttled so a frame's burst of overlaps stays one clink, not a buzz.
    if (relVel < -_clinkSpeed && _clinkCooldown <= 0) {
      _clinkCooldown = _clinkInterval;
      AudioManager.instance.playClawClink();
    }
    final j = -(1 + ballRestitution) * relVel / 2;
    a.velocity.x -= j * nx;
    a.velocity.y -= j * ny;
    b.velocity.x += j * nx;
    b.velocity.y += j * ny;
  }

  void _resolveClawArms() {
    final shoulderY = clawY + ClawCabinet.headH - ClawCabinet.armOverlap;
    for (final isLeft in [true, false]) {
      final shoulderX = clawX + (isLeft ? -2.0 : 2.0);
      final angle = clawClosed
          ? (isLeft ? -0.12 : 0.12)
          : (isLeft ? 0.32 : -0.32);
      // Arm hangs from anchor topCenter and rotates by `angle`. In Flame's
      // y-down coords positive angle is visual CW, so the local-down axis
      // (0, 1) rotates to (-sin, cos).
      final tipX = shoulderX - math.sin(angle) * ClawCabinet.armH;
      final tipY = shoulderY + math.cos(angle) * ClawCabinet.armH;
      for (final s in _floorSpheres) {
        _resolveSphereSegment(s, shoulderX, shoulderY, tipX, tipY);
      }
    }
  }

  void _resolveSphereSegment(
    SphereComponent s,
    double ax,
    double ay,
    double bx,
    double by,
  ) {
    final ex = bx - ax;
    final ey = by - ay;
    final lenSq = ex * ex + ey * ey;
    if (lenSq < 0.0001) return;
    var t = ((s.position.x - ax) * ex + (s.position.y - ay) * ey) / lenSq;
    t = t.clamp(0.0, 1.0);
    final cx = ax + t * ex;
    final cy = ay + t * ey;
    final ndx = s.position.x - cx;
    final ndy = s.position.y - cy;
    final dSq = ndx * ndx + ndy * ndy;
    final minDist = SphereComponent.physicsRadius + armHalfWidth;
    if (dSq >= minDist * minDist) return;
    final d = math.sqrt(math.max(dSq, 0.0001));
    final nx = ndx / d;
    final ny = ndy / d;
    final overlap = minDist - d;
    s.position.x += nx * overlap;
    s.position.y += ny * overlap;
    // Cancel the inward component of velocity so the sphere doesn't keep
    // tunneling into the arm next frame.
    final vIntoSeg = -(s.velocity.x * nx + s.velocity.y * ny);
    if (vIntoSeg > 0) {
      s.velocity.x += nx * vIntoSeg;
      s.velocity.y += ny * vIntoSeg;
    }
  }

  // ─── Public input API ───────────────────────────────────────────────

  void setStickDir(int dir) {
    stickDir = dir.clamp(-1, 1);
  }

  Future<void> requestDrop() async {
    if (phase != ClawPhase.aiming) return;
    stickDir = 0;
    await _runDropSequence();
  }

  // ─── Drop / grab / deliver ──────────────────────────────────────────

  Future<void> _runDropSequence() async {
    phase = ClawPhase.dropping;
    await _animateClawY(
      to: ClawCabinet.clawDropY,
      curve: Curves.easeIn,
      duration: 0.6,
    );

    phase = ClawPhase.grabbing;
    clawClosed = true;
    final caught = _findCaughtSphere();
    if (caught != null) {
      _floorSpheres.remove(caught);
      caught.removeFromParent();
      final captured = _cloneSphere(caught, Vector2(clawX, clawY), 5);
      capturedSphere = captured;
      _cabinet.add(captured);
      _ownedSiblings.add(captured);
    }
    await Future<void>.delayed(const Duration(milliseconds: 350));

    phase = ClawPhase.retracting;
    await _animateClawY(
      to: ClawCabinet.clawRestY,
      curve: Curves.easeOut,
      duration: 0.6,
    );

    if (capturedSphere == null) {
      clawClosed = false;
      phase = ClawPhase.result;
      _dispatchResult();
      return;
    }

    phase = ClawPhase.delivering;
    await _animateClawX(
      to: ClawCabinet.prizeDoorX + ClawCabinet.prizeDoorW / 2,
      curve: Curves.easeInOut,
      duration: 0.7,
    );

    // "Drop into the chute" in two layers:
    //  1. Free-fall tween at priority 5 (below exterior 6) so the ball
    //     vanishes behind the body once it clears the glass floor.
    //  2. Open the door and spawn a "settled" sphere at priority 9 (above
    //     the door at 8) so it appears inside the hatch.
    clawClosed = false;
    final ball = capturedSphere!;
    capturedSphere = null;
    _droppedSphere = ball;
    await _animateDroppedSphereY(
      from: ball.position.y,
      to: ClawCabinet.glassFloorY + 14,
      duration: 0.32,
    );
    _droppedSphere = null;
    ball.removeFromParent();
    _ownedSiblings.remove(ball);

    await Future<void>.delayed(const Duration(milliseconds: 120));
    final settled = _cloneSphere(
      ball,
      Vector2(
        ClawCabinet.prizeDoorX + ClawCabinet.prizeDoorW / 2,
        ClawCabinet.prizeDoorY + ClawCabinet.prizeDoorH - 6,
      ),
      9,
    );
    _cabinet.add(settled);
    _ownedSiblings.add(settled);
    doorOpen = true;
    AudioManager.instance.playClawPrizeDrop();
    _won = true;
    _spheresWon = 1;
    if (ball is PrizeSphereComponent) _wonPrize = ball.collectible;
    await Future<void>.delayed(const Duration(milliseconds: 550));
    doorOpen = false;
    settled.removeFromParent();
    _ownedSiblings.remove(settled);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    phase = ClawPhase.result;
    _dispatchResult();
  }

  Future<void> _animateDroppedSphereY({
    required double from,
    required double to,
    required double duration,
  }) {
    final completer = Completer<void>();
    _dropAnim = _Anim(
      from: from,
      to: to,
      duration: duration,
      curve: Curves.easeIn,
      onDone: completer.complete,
    );
    return completer.future;
  }

  SphereComponent? _findCaughtSphere() {
    // Mouth of the closed claw, between the arm tips. 2-D distance so
    // airborne (jostled) spheres stay catchable, not just floor-resting ones.
    final mouthX = clawX;
    final mouthY = clawY +
        ClawCabinet.headH -
        ClawCabinet.armOverlap +
        ClawCabinet.armH * 0.7;
    SphereComponent? best;
    var bestDist = ClawCabinet.captureRadius;
    for (final s in _floorSpheres) {
      final dx = s.position.x - mouthX;
      final dy = s.position.y - mouthY;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d < bestDist) {
        best = s;
        bestDist = d;
      }
    }
    return best;
  }

  void _dispatchResult() {
    if (_resultDispatched) return;
    _resultDispatched = true;
    onResultReady(won: _won, spheresWon: _spheresWon, prize: _wonPrize);
  }

  /// Spawn a new sphere of the same kind as [source] at [position]. Prize
  /// spheres reuse the source's decoded sprite + composed shell so the clone
  /// renders on its first frame.
  SphereComponent _cloneSphere(
    SphereComponent source,
    Vector2 position,
    int priority,
  ) {
    if (source is PrizeSphereComponent) {
      return source.cloneAt(position: position, priority: priority);
    }
    return SphereComponent(
      color: source.color,
      position: position,
      priority: priority,
    );
  }

  Future<void> _animateClawX({
    required double to,
    required Curve curve,
    required double duration,
  }) {
    final completer = Completer<void>();
    _xAnim = _Anim(
      from: clawX,
      to: to,
      duration: duration,
      curve: curve,
      onDone: completer.complete,
    );
    return completer.future;
  }

  Future<void> _animateClawY({
    required double to,
    required Curve curve,
    required double duration,
  }) {
    final completer = Completer<void>();
    _yAnim = _Anim(
      from: clawY,
      to: to,
      duration: duration,
      curve: curve,
      onDone: completer.complete,
    );
    return completer.future;
  }
}

/// One-shot tween advanced by the Flame tick. `tick` returns `null` on
/// completion so a `_Anim?` field self-clears.
class _Anim {
  final double from;
  final double to;
  final double duration;
  final Curve curve;
  final VoidCallback onDone;
  double _elapsed = 0;
  bool _done = false;

  _Anim({
    required this.from,
    required this.to,
    required this.duration,
    required this.curve,
    required this.onDone,
  });

  _Anim? tick(double dt, ValueChanged<double> setter) {
    if (_done) return null;
    _elapsed += dt;
    final t = (_elapsed / duration).clamp(0.0, 1.0);
    setter(from + (to - from) * curve.transform(t));
    if (t >= 1.0) {
      _done = true;
      onDone();
      return null;
    }
    return this;
  }
}
