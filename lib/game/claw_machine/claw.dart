import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../lexaway_game.dart';
import 'cabinet.dart';
import 'claw_session.dart';

/// The cable that hangs from the cabinet ceiling down to the top of the
/// claw head. Reads each frame from the active session.
class CableComponent extends PositionComponent
    with HasGameReference<LexawayGame> {
  final ClawSessionComponent session;
  CableComponent({required this.session}) : super(priority: 2);

  static final Paint _paint = Paint()..color = const Color(0xFF000000);

  @override
  void update(double dt) {
    super.update(dt);
    position = Vector2(
      session.clawX - 1,
      ClawCabinet.glassTop,
    );
    final h = math.max(0.0, session.clawY - ClawCabinet.glassTop);
    size = Vector2(2, h);
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(Offset.zero & size.toSize(), _paint);
  }
}

/// The compact "spool" head — bottom 16-px slice of ClawBase.png.
class ClawHeadComponent extends PositionComponent
    with HasGameReference<LexawayGame> {
  final ClawSessionComponent session;
  late final Image _image;
  late final Paint _paint;
  static final Rect _src = const Rect.fromLTWH(0, 32, 24, 16);

  ClawHeadComponent({required this.session})
      : super(
          size: Vector2(ClawCabinet.headW, ClawCabinet.headH),
          priority: 4,
        );

  @override
  Future<void> onLoad() async {
    _image = await game.images.load('claw_machine/ClawBase.png');
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

/// One of the two claw prongs. Pivots around its top-center (the
/// "shoulder") via [Anchor.topCenter]. The right arm renders its sprite
/// horizontally mirrored so the same Claw1Trimmed/Claw2Trimmed image
/// produces a symmetric pair.
class ClawArmComponent extends PositionComponent
    with HasGameReference<LexawayGame> {
  final ClawSessionComponent session;
  final bool isLeft;
  late final Image _open;
  late final Image _closed;
  late final Paint _paint;

  ClawArmComponent({required this.session, required this.isLeft})
      : super(
          size: Vector2(ClawCabinet.armW, ClawCabinet.armH),
          anchor: Anchor.topCenter,
          priority: 3,
        );

  @override
  Future<void> onLoad() async {
    _open = await game.images.load('claw_machine/Claw1Trimmed.png');
    _closed = await game.images.load('claw_machine/Claw2Trimmed.png');
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
    final shoulderX = session.clawX + (isLeft ? -2.0 : 2.0);
    position = Vector2(shoulderX, shoulderY);
    angle = _armAngle(closed: session.clawClosed, isLeft: isLeft);
  }

  static double _armAngle({required bool closed, required bool isLeft}) {
    if (closed) {
      return isLeft ? -0.18 : 0.18;
    }
    return isLeft ? 0.7 : -0.7;
  }

  @override
  void render(Canvas canvas) {
    final image = session.clawClosed ? _closed : _open;
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final dst = Offset.zero & size.toSize();
    if (isLeft) {
      canvas.drawImageRect(image, src, dst, _paint);
    } else {
      canvas.save();
      canvas.translate(size.x, 0);
      canvas.scale(-1, 1);
      canvas.drawImageRect(image, src, dst, _paint);
      canvas.restore();
    }
  }
}
