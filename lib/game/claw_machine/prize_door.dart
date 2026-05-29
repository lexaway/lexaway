import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../lexaway_game.dart';
import 'cabinet.dart';
import 'claw_session.dart';

/// Prize hatch on the cabinet console. Driven by the active session's
/// [doorOpen] flag. The art is a single 3-frame sheet (84×20, three 28×20
/// cells: open / half / closed), so instead of snapping between two images
/// we ease a 0→1 progress toward the flag and pick the matching frame —
/// giving a quick two-step open/close animation.
class PrizeDoorComponent extends PositionComponent
    with HasGameReference<LexawayGame>, ZoomFaded {
  final ClawSessionComponent session;
  late final Image _sheet;
  late final Paint _paint;

  // 0 = fully closed, 1 = fully open. Eased toward [session.doorOpen].
  double _progress = 0;
  static const double _cellW = 28;
  static const double _cellH = 20;
  // ~6 units/sec → a full open or close takes ~0.17s (a frame each way).
  static const double _animSpeed = 6.0;

  PrizeDoorComponent({required this.session})
      : super(
          position: Vector2(
            ClawCabinet.prizeDoorX,
            ClawCabinet.prizeDoorY,
          ),
          size: Vector2(
            ClawCabinet.prizeDoorW,
            ClawCabinet.prizeDoorH,
          ),
          priority: 8,
        );

  @override
  Future<void> onLoad() async {
    _sheet = await game.images.load('claw_machine/prize_door.png');
    _paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final target = session.doorOpen ? 1.0 : 0.0;
    if (_progress < target) {
      _progress = math.min(target, _progress + _animSpeed * dt);
    } else if (_progress > target) {
      _progress = math.max(target, _progress - _animSpeed * dt);
    }
  }

  // Frame 0 open, 1 half, 2 closed.
  int get _frame => _progress > 0.66
      ? 0
      : (_progress > 0.33 ? 1 : 2);

  @override
  void render(Canvas canvas) {
    final src = Rect.fromLTWH(_frame * _cellW, 0, _cellW, _cellH);
    canvas.drawImageRect(_sheet, src, Offset.zero & size.toSize(), _paint);
  }
}
