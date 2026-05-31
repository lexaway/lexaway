import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/services.dart';

import '../audio_manager.dart';
import '../lexaway_game.dart';
import 'cabinet.dart';
import 'claw_session.dart';

/// "Drop the claw" button. Tap-down triggers the drop sequence (and a
/// haptic blip); tap-up restores the unpressed sprite. Sprite sheet is
/// 24×8, 2 cells of 12×8 — col 0 is unpressed, col 1 pressed.
class ActionButtonComponent extends PositionComponent
    with HasGameReference<LexawayGame>, TapCallbacks, ZoomFaded {
  final ClawSessionComponent session;
  late final Image _sheet;
  late final Paint _paint;
  bool _pressed = false;

  ActionButtonComponent({required this.session})
      : super(
          position: Vector2(
            ClawCabinet.buttonX,
            ClawCabinet.buttonY,
          ),
          size: Vector2(
            ClawCabinet.buttonW,
            ClawCabinet.buttonH,
          ),
          priority: 10,
        );

  @override
  Future<void> onLoad() async {
    _sheet = await game.images.load('claw_machine/button.png');
    _paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
  }

  bool get _enabled => session.phase == ClawPhase.aiming;

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (!_enabled) return;
    _pressed = true;
    HapticFeedback.lightImpact();
    AudioManager.instance.playClawDropButton();
    // Match the original 80 ms press flash, but the drop fires
    // immediately — releasing the press before the drop completes
    // would otherwise ship a stale "pressed" frame.
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      _pressed = false;
    });
    session.requestDrop();
  }

  @override
  void onTapUp(TapUpEvent event) {
    super.onTapUp(event);
    _pressed = false;
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    super.onTapCancel(event);
    _pressed = false;
  }

  @override
  void render(Canvas canvas) {
    final src = Rect.fromLTWH(_pressed ? 12 : 0, 0, 12, 8);
    canvas.drawImageRect(_sheet, src, Offset.zero & size.toSize(), _paint);
  }
}
