import 'dart:ui';

import 'package:flame/components.dart';

import '../lexaway_game.dart';
import 'cabinet.dart';
import 'claw_session.dart';

/// Bottom-left prize hatch on the cabinet. Swaps between PrizeDoor1 (closed)
/// and PrizeDoor2 (open) based on the active session's [doorOpen] flag.
class PrizeDoorComponent extends PositionComponent
    with HasGameReference<LexawayGame> {
  final ClawSessionComponent session;
  late final Sprite _closed;
  late final Sprite _open;
  late final Paint _paint;

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
    final closedImg =
        await game.images.load('claw_machine/PrizeDoor1.png');
    final openImg = await game.images.load('claw_machine/PrizeDoor2.png');
    _closed = Sprite(closedImg);
    _open = Sprite(openImg);
    _paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
  }

  @override
  void render(Canvas canvas) {
    final sprite = session.doorOpen ? _open : _closed;
    sprite.render(canvas, size: size, overridePaint: _paint);
  }
}
