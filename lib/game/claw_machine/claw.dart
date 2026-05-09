import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../claw_machine_game.dart';

/// The cable that hangs from the cabinet ceiling down to the top of the
/// claw head. Read each frame from [ClawMachineGame.clawX]/[clawY] and
/// drawn as a 2-cabinet-px black rect.
class CableComponent extends PositionComponent
    with HasGameReference<ClawMachineGame> {
  CableComponent() : super(priority: 2);

  static final Paint _paint = Paint()..color = const Color(0xFF000000);

  @override
  void update(double dt) {
    super.update(dt);
    position = Vector2(
      game.clawX - 1,
      ClawMachineGame.glassTop,
    );
    final h = math.max(0.0, game.clawY - ClawMachineGame.glassTop);
    size = Vector2(2, h);
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(Offset.zero & size.toSize(), _paint);
  }
}

/// The compact "spool" head — bottom 16-px slice of ClawBase.png. Reads
/// the claw position from the game each frame.
class ClawHeadComponent extends PositionComponent
    with HasGameReference<ClawMachineGame> {
  late final Image _image;
  late final Paint _paint;
  static final Rect _src = const Rect.fromLTWH(0, 32, 24, 16);

  ClawHeadComponent()
      : super(
          size: Vector2(ClawMachineGame.headW, ClawMachineGame.headH),
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
    position = Vector2(game.clawX - ClawMachineGame.headW / 2, game.clawY);
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
    with HasGameReference<ClawMachineGame> {
  final bool isLeft;
  late final Image _open;
  late final Image _closed;
  late final Paint _paint;

  ClawArmComponent({required this.isLeft})
      : super(
          size: Vector2(ClawMachineGame.armW, ClawMachineGame.armH),
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
    final shoulderY = game.clawY +
        ClawMachineGame.headH -
        ClawMachineGame.armOverlap;
    final shoulderX = game.clawX + (isLeft ? -2.0 : 2.0);
    position = Vector2(shoulderX, shoulderY);
    angle = _armAngle(closed: game.clawClosed, isLeft: isLeft);
  }

  static double _armAngle({required bool closed, required bool isLeft}) {
    if (closed) {
      return isLeft ? -0.18 : 0.18;
    }
    return isLeft ? 0.7 : -0.7;
  }

  @override
  void render(Canvas canvas) {
    final image = game.clawClosed ? _closed : _open;
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
