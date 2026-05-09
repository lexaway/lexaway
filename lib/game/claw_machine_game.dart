import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import 'claw_machine/action_button.dart';
import 'claw_machine/cabinet.dart';
import 'claw_machine/claw.dart';
import 'claw_machine/joystick.dart';
import 'claw_machine/prize_door.dart';
import 'claw_machine/sphere.dart';

/// Phases of a single attempt. The state machine matches the previous
/// pure-Flutter overlay so feel is preserved.
enum ClawPhase { aiming, dropping, grabbing, retracting, delivering, result }

/// Callback signature for [ClawMachineGame.onResultReady]. The game
/// surfaces only the gameplay outcome; the overlay layers `coinsSpent`
/// on when it forwards the public [ClawResult].
typedef ClawAttemptCallback = void Function({
  required bool won,
  required int spheresWon,
});

/// Self-contained mini-game: a 80×128 cabinet-local coordinate space,
/// rendered into whatever viewport the hosting `GameWidget` provides.
/// All input (joystick + button) is handled by Flame components, so the
/// hosting overlay only has to wire up the result splash.
class ClawMachineGame extends FlameGame {
  // Cabinet-local geometry. Lifted unchanged from the previous overlay so
  // the game looks pixel-for-pixel the same.
  static const double cabW = 80;
  static const double cabH = 128;
  static const double glassTop = 12;
  static const double glassLeft = 8;
  static const double glassRight = 72;
  static const double glassFloorY = 72;
  static const double glassCenterX = (glassLeft + glassRight) / 2;
  static const double headW = 24;
  static const double headH = 16;
  static const double armOverlap = 10;
  static const double armW = 18;
  static const double armH = 22;
  static const double clawRestY = glassTop + 2;
  static const double clawDropY =
      glassFloorY - (headH - armOverlap) - armH;
  static const double captureRadius = 10;
  static const double prizeDoorX = 18;
  static const double prizeDoorY = 105;
  static const double prizeDoorW = 24;
  static const double prizeDoorH = 20;
  static const double stickX = 48;
  static const double stickY = 70;
  static const double stickW = 24;
  static const double stickH = 27;
  static const double buttonX = 16;
  static const double buttonY = 80;
  static const double buttonW = 16;
  static const double buttonH = 16;
  // Old overlay used 0.8 px per ~16 ms tick. In continuous time that's
  // ~50 px/s — keep the same on-screen feel.
  static const double stickSpeedPerSec = 50.0;

  // Physics tuning. Cabinet is 80×128 px so values are small in absolute
  // terms — gravity pulls a sphere across the cabinet floor in ~0.6 s.
  static const double gravityPerSec2 = 220.0;
  static const double wallRestitution = 0.35;
  static const double ballRestitution = 0.55;
  static const double groundFriction = 6.0;
  static const double restSpeed = 1.5;
  static const double armHalfWidth = 3.0;

  /// Fired once when the attempt has resolved and the result splash should
  /// open in Flutter land. Mirrors `EggPreviewGame.onAllPhasesComplete`.
  final ClawAttemptCallback onResultReady;

  ClawMachineGame({required this.onResultReady});

  // Public state — components read these every frame and self-position.
  ClawPhase phase = ClawPhase.aiming;
  double clawX = glassCenterX;
  double clawY = clawRestY;
  bool clawClosed = false;
  bool doorOpen = false;
  int stickDir = 0;
  SphereComponent? capturedSphere;

  bool _won = false;
  int _spheresWon = 0;
  bool _resultDispatched = false;

  late final PositionComponent root;
  final List<SphereComponent> _floorSpheres = [];

  _Anim? _xAnim;
  _Anim? _yAnim;
  // Drives the captured-sphere "fall into the chute" tween. Its target is
  // [_droppedSphere], a separate field from [capturedSphere] so the
  // snap-to-claw assignment in update() doesn't fight the tween.
  _Anim? _dropAnim;
  SphereComponent? _droppedSphere;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    final scale = _fitScale(size);
    root = PositionComponent(
      size: Vector2(cabW, cabH),
      scale: Vector2.all(scale),
      position: _rootPosition(size, scale),
    );
    add(root);

    // Five spheres on the floor of the glass, lightly jittered.
    final colors = <Color>[
      const Color(0xFFFF4081),
      const Color(0xFFFFCA28),
      const Color(0xFF40C4FF),
      const Color(0xFF66BB6A),
      const Color(0xFFAB47BC),
    ];
    final rng = math.Random();
    final spacing = (glassRight - glassLeft) / (colors.length + 1);
    for (var i = 0; i < colors.length; i++) {
      // Drop them in from a few px above the floor with a tiny random
      // velocity so the opening jostle feels lively.
      final s = SphereComponent(
        color: colors[i],
        position: Vector2(
          glassLeft + spacing * (i + 1) + (rng.nextDouble() - 0.5) * 6,
          glassFloorY - 30 + rng.nextDouble() * 8,
        ),
      );
      s.velocity.x = (rng.nextDouble() - 0.5) * 20;
      _floorSpheres.add(s);
      root.add(s);
    }

    root.add(CableComponent());
    root.add(ClawArmComponent(isLeft: true));
    root.add(ClawArmComponent(isLeft: false));
    root.add(ClawHeadComponent());
    root.add(ExteriorComponent());
    root.add(GlassShineComponent());
    root.add(PrizeDoorComponent());
    root.add(ClawJoystickComponent());
    root.add(ActionButtonComponent());
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (!isMounted) return;
    final scale = _fitScale(size);
    root.scale = Vector2.all(scale);
    root.position = _rootPosition(size, scale);
  }

  static double _fitScale(Vector2 viewport) =>
      math.min(viewport.x / cabW, viewport.y / cabH);

  static Vector2 _rootPosition(Vector2 viewport, double scale) => Vector2(
        (viewport.x - cabW * scale) / 2,
        (viewport.y - cabH * scale) / 2,
      );

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
          .clamp(glassLeft, glassRight);
    }

    _stepPhysics(dt);

    if (capturedSphere != null) {
      capturedSphere!.position = Vector2(
        clawX,
        clawY + (headH - armOverlap) + armH - 14 + 5,
      );
    }
  }

  // ─── Physics ────────────────────────────────────────────────────────

  /// Integrate gravity, resolve sphere-sphere overlap, clamp to glass walls,
  /// and let the claw arms (segment colliders) shove spheres aside. Cheap
  /// O(n²) all the way through — we have five spheres, so it doesn't matter.
  void _stepPhysics(double dt) {
    if (_floorSpheres.isEmpty) return;
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
      if (s.position.x < glassLeft + r) {
        s.position.x = glassLeft + r;
        if (s.velocity.x < 0) s.velocity.x = -s.velocity.x * wallRestitution;
      } else if (s.position.x > glassRight - r) {
        s.position.x = glassRight - r;
        if (s.velocity.x > 0) s.velocity.x = -s.velocity.x * wallRestitution;
      }
      if (s.position.y > glassFloorY - r) {
        s.position.y = glassFloorY - r;
        if (s.velocity.y > 0) {
          s.velocity.y = s.velocity.y.abs() < restSpeed
              ? 0
              : -s.velocity.y * wallRestitution;
        }
        // Friction on the floor — exponential decay toward zero.
        s.velocity.x -= s.velocity.x * (1 - math.exp(-groundFriction * dt));
        if (s.velocity.x.abs() < 0.5) s.velocity.x = 0;
      } else if (s.position.y < glassTop + r) {
        s.position.y = glassTop + r;
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
    final j = -(1 + ballRestitution) * relVel / 2;
    a.velocity.x -= j * nx;
    a.velocity.y -= j * ny;
    b.velocity.x += j * nx;
    b.velocity.y += j * ny;
  }

  void _resolveClawArms() {
    final shoulderY = clawY + headH - armOverlap;
    for (final isLeft in [true, false]) {
      final shoulderX = clawX + (isLeft ? -2.0 : 2.0);
      final angle = clawClosed
          ? (isLeft ? -0.18 : 0.18)
          : (isLeft ? 0.7 : -0.7);
      // Arm hangs from anchor topCenter and rotates by `angle`. In Flame's
      // y-down coords positive angle is visual CW, so the local-down axis
      // (0, 1) rotates to (-sin, cos).
      final tipX = shoulderX - math.sin(angle) * armH;
      final tipY = shoulderY + math.cos(angle) * armH;
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
      to: clawDropY,
      curve: Curves.easeIn,
      duration: 0.6,
    );

    phase = ClawPhase.grabbing;
    clawClosed = true;
    final caught = _findCaughtSphere();
    if (caught != null) {
      _floorSpheres.remove(caught);
      caught.removeFromParent();
      capturedSphere = SphereComponent(
        color: caught.color,
        position: Vector2(clawX, clawY),
        priority: 5,
      );
      root.add(capturedSphere!);
    }
    await Future<void>.delayed(const Duration(milliseconds: 350));

    phase = ClawPhase.retracting;
    await _animateClawY(
      to: clawRestY,
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
      to: prizeDoorX + prizeDoorW / 2,
      curve: Curves.easeInOut,
      duration: 0.7,
    );

    // Two-layer "drop into the chute" hack:
    //  1. Open the claw, hand the captured sphere off to a free-falling
    //     tween. Its priority (5) is below the cabinet exterior (6), so the
    //     moment it crosses the glass floor it disappears behind the body.
    //  2. After a beat, open the prize door and spawn a "settled" sphere at
    //     priority 9 (above the door at 8) so it appears inside the hatch.
    clawClosed = false;
    final ball = capturedSphere!;
    final ballColor = ball.color;
    capturedSphere = null;
    _droppedSphere = ball;
    await _animateDroppedSphereY(
      from: ball.position.y,
      to: glassFloorY + 14,
      duration: 0.32,
    );
    _droppedSphere = null;
    ball.removeFromParent();

    await Future<void>.delayed(const Duration(milliseconds: 120));
    final settled = SphereComponent(
      color: ballColor,
      position: Vector2(
        prizeDoorX + prizeDoorW / 2,
        prizeDoorY + prizeDoorH - 6,
      ),
      priority: 9,
    );
    root.add(settled);
    doorOpen = true;
    _won = true;
    _spheresWon = 1;
    await Future<void>.delayed(const Duration(milliseconds: 550));
    doorOpen = false;
    settled.removeFromParent();
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
    // Mouth of the closed claw — between the two arm tips, just below the
    // shoulders. Spheres that are within `captureRadius` of this point get
    // caught. Using a 2-D distance keeps airborne (jostled) spheres
    // catchable, not just the row sitting on the floor.
    final mouthX = clawX;
    final mouthY = clawY + headH - armOverlap + armH * 0.7;
    SphereComponent? best;
    var bestDist = captureRadius;
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
    onResultReady(won: _won, spheresWon: _spheresWon);
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

/// One-shot tween advanced by the Flame tick. `tick` returns `null` when
/// the tween has completed (matching the pattern of consuming a `_Anim?`
/// field, so the field self-clears).
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
