import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../lexaway_game.dart';
import 'cabinet.dart';
import 'claw_session.dart';

enum _StickPose { center, right, left }

/// Aim control. Drag horizontally — left half steers the claw left,
/// right half steers it right, middle releases. The dirty-fraction
/// threshold (0.4 / 0.6) and the three-pose look match the previous
/// Flutter overlay exactly.
class ClawJoystickComponent extends PositionComponent
    with HasGameReference<LexawayGame>, DragCallbacks, ZoomFaded {
  final ClawSessionComponent session;
  late final Image _sheet;
  late final Paint _paint;
  _StickPose _pose = _StickPose.center;

  // Sheet layout: a single row of 3 cells, 28×20 each. Cols 0/1/2 are
  // center (upright) / right-lean / left-lean.
  static const double _cellW = 28;
  static const double _cellH = 20;

  ClawJoystickComponent({required this.session})
      : super(
          position: Vector2(
            ClawCabinet.stickX,
            ClawCabinet.stickY,
          ),
          size: Vector2(
            ClawCabinet.stickW,
            ClawCabinet.stickH,
          ),
          priority: 9,
        );

  @override
  Future<void> onLoad() async {
    _sheet = await game.images.load('claw_machine/joystick.png');
    _paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
  }

  bool get _enabled => session.phase == ClawPhase.aiming;

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
    session.setStickDir(dir);
    _pose = dir > 0
        ? _StickPose.right
        : (dir < 0 ? _StickPose.left : _StickPose.center);
  }

  void _release() {
    session.setStickDir(0);
    _pose = _StickPose.center;
  }

  @override
  void render(Canvas canvas) {
    final col = switch (_pose) {
      _StickPose.center => 0,
      _StickPose.right => 1,
      _StickPose.left => 2,
    };
    final src = Rect.fromLTWH(col * _cellW, 0, _cellW, _cellH);
    canvas.drawImageRect(_sheet, src, Offset.zero & size.toSize(), _paint);
  }
}
