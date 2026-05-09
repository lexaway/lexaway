import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../claw_machine_game.dart';

enum _StickPose { center, right, left }

/// Aim control. Drag horizontally — left half steers the claw left,
/// right half steers it right, middle releases. The dirty-fraction
/// threshold (0.4 / 0.6) and the three-pose look match the previous
/// Flutter overlay exactly.
class ClawJoystickComponent extends PositionComponent
    with HasGameReference<ClawMachineGame>, DragCallbacks {
  late final Image _sheet;
  late final Paint _paint;
  _StickPose _pose = _StickPose.center;

  // Sheet layout: 5×3 cells of 24×27 each. Row 2 (green) is the colorway
  // we want; cols 0/1/2 are center/right/left.
  static const double _cellW = 24;
  static const double _cellH = 27;

  ClawJoystickComponent()
      : super(
          position: Vector2(
            ClawMachineGame.stickX,
            ClawMachineGame.stickY,
          ),
          size: Vector2(
            ClawMachineGame.stickW,
            ClawMachineGame.stickH,
          ),
          priority: 9,
        );

  @override
  Future<void> onLoad() async {
    _sheet = await game.images.load('claw_machine/Joystick.png');
    _paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
  }

  bool get _enabled => game.phase == ClawPhase.aiming;

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (!_enabled) return;
    _applyDir(event.localPosition.x / size.x);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (!_enabled) return;
    _applyDir(event.localEndPosition.x / size.x);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _release();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _release();
  }

  void _applyDir(double fraction) {
    final f = fraction.clamp(0.0, 1.0);
    final dir = f > 0.6
        ? 1
        : f < 0.4
            ? -1
            : 0;
    game.setStickDir(dir);
    _pose = dir > 0
        ? _StickPose.right
        : (dir < 0 ? _StickPose.left : _StickPose.center);
  }

  void _release() {
    game.setStickDir(0);
    _pose = _StickPose.center;
  }

  @override
  void render(Canvas canvas) {
    final col = switch (_pose) {
      _StickPose.center => 0,
      _StickPose.right => 1,
      _StickPose.left => 2,
    };
    final src = Rect.fromLTWH(col * _cellW, 2 * _cellH, _cellW, _cellH);
    canvas.drawImageRect(_sheet, src, Offset.zero & size.toSize(), _paint);
  }
}
