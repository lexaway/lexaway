import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../lexaway_game.dart';
import 'cabinet.dart';
import 'claw_session.dart';

/// Cable from the cabinet ceiling to the top of the claw head. Coloured to
/// match the cream rod hook_base.png draws above the spool bulb (the bulb
/// itself is the [ClawHeadComponent] slice).
class CableComponent extends PositionComponent
    with HasGameReference<LexawayGame>, ZoomFaded {
  final ClawSessionComponent session;
  CableComponent({required this.session}) : super(priority: 2);

  static final Paint _paint = Paint()..color = const Color(0xFFF9D597);

  @override
  void update(double dt) {
    super.update(dt);
    position = Vector2(
      session.clawX - 2,
      ClawCabinet.glassTop,
    );
    final h = math.max(0.0, session.clawY - ClawCabinet.glassTop);
    size = Vector2(4, h);
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(Offset.zero & size.toSize(), _paint);
  }
}

/// The "spool" head — pink bulb at the bottom of hook_base.png (the rod
/// above it is [CableComponent]). Sheet is 2×, so the bulb lives in the
/// 36×36 sub-rect below the rod.
class ClawHeadComponent extends PositionComponent
    with HasGameReference<LexawayGame>, ZoomFaded {
  final ClawSessionComponent session;
  late final Image _image;
  late final Paint _paint;
  static final Rect _src = const Rect.fromLTWH(18, 35, 36, 36);

  ClawHeadComponent({required this.session})
      : super(
          size: Vector2(ClawCabinet.headW, ClawCabinet.headH),
          priority: 4,
        );

  @override
  Future<void> onLoad() async {
    _image = await game.images.load('claw_machine/hook_base.png');
    _paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
  }

  @override
  void update(double dt) {
    super.update(dt);
    position = Vector2(
      session.clawX - ClawCabinet.headW / 2,
      session.clawY,
    );
  }

  @override
  void render(Canvas canvas) {
    canvas.drawImageRect(
      _image,
      _src,
      Offset.zero & size.toSize(),
      _paint,
    );
  }
}

/// One of the two claw prongs. Pivots around its top-center "shoulder" via
/// [Anchor.topCenter]. Art is a mirrored pair (hook_left / hook_right) with
/// no open/closed frame — open/closed is rotation alone.
class ClawArmComponent extends PositionComponent
    with HasGameReference<LexawayGame>, ZoomFaded {
  final ClawSessionComponent session;
  final bool isLeft;
  late final Image _prong;
  late final Paint _paint;

  ClawArmComponent({required this.session, required this.isLeft})
      : super(
          size: Vector2(ClawCabinet.armW, ClawCabinet.armH),
          anchor: Anchor.topCenter,
          priority: 3,
        );

  @override
  Future<void> onLoad() async {
    _prong = await game.images.load(
      isLeft ? 'claw_machine/hook_left.png' : 'claw_machine/hook_right.png',
    );
    _paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final shoulderY = session.clawY +
        ClawCabinet.headH -
        ClawCabinet.armOverlap;
    final shoulderX = session.clawX + (isLeft ? -3.5 : 3.5);
    position = Vector2(shoulderX, shoulderY);
    angle = _armAngle(closed: session.clawClosed, isLeft: isLeft);
  }

  static double _armAngle({required bool closed, required bool isLeft}) {
    if (closed) {
      return isLeft ? -0.12 : 0.12;
    }
    return isLeft ? 0.32 : -0.32;
  }

  @override
  void render(Canvas canvas) {
    canvas.drawImageRect(
      _prong,
      Rect.fromLTWH(
        0,
        0,
        _prong.width.toDouble(),
        _prong.height.toDouble(),
      ),
      Offset.zero & size.toSize(),
      _paint,
    );
  }
}
