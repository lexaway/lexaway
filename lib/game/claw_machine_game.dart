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
      final s = SphereComponent(
        color: colors[i],
        position: Vector2(
          glassLeft + spacing * (i + 1) + (rng.nextDouble() - 0.5) * 4,
          glassFloorY - 5,
        ),
      );
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

    if (phase == ClawPhase.aiming && stickDir != 0) {
      clawX = (clawX + stickDir * stickSpeedPerSec * dt)
          .clamp(glassLeft, glassRight);
    }

    if (capturedSphere != null) {
      capturedSphere!.position = Vector2(
        clawX,
        clawY + (headH - armOverlap) + armH - 14 + 5,
      );
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
    doorOpen = true;
    await Future<void>.delayed(const Duration(milliseconds: 200));
    clawClosed = false;
    capturedSphere?.removeFromParent();
    capturedSphere = null;
    _won = true;
    _spheresWon = 1;
    await Future<void>.delayed(const Duration(milliseconds: 400));
    doorOpen = false;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    phase = ClawPhase.result;
    _dispatchResult();
  }

  SphereComponent? _findCaughtSphere() {
    SphereComponent? best;
    var bestDist = captureRadius;
    for (final s in _floorSpheres) {
      final d = (s.position.x - clawX).abs();
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
