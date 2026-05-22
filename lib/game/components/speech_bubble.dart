import 'dart:ui' as ui;

import 'package:flame/components.dart';

import '../lexaway_game.dart';
import 'bubble_painter.dart';

class SpeechBubble extends PositionComponent {
  static const double _scale = LexawayGame.pixelScale;
  static const double _padding = 2; // inner padding at native pixel res
  static const double _showDuration = 2.5;

  /// The component the bubble hovers over. Injected so the bubble doesn't
  /// need to know about `game.player` (or anything else in the game tree).
  final PositionComponent follow;

  String _fontFamily;

  /// The currently-rendered font family. Setting this rebuilds the paragraph
  /// in place so a font swap from Settings is reflected mid-game without
  /// waiting for the next [show] call.
  String get fontFamily => _fontFamily;
  set fontFamily(String value) {
    if (value == _fontFamily) return;
    _fontFamily = value;
    if (_loaded && _visible) {
      _buildParagraph(_text);
      _layout();
    }
  }

  SpeechBubble({required this.follow, required String fontFamily})
      : _fontFamily = fontFamily;

  late NineTileBox _box;
  late ui.Paint _paint;
  String _text = '';
  double _timer = 0;
  bool _visible = false;
  bool _loaded = false;
  bool _muted = false;

  /// When muted, [show] is a no-op and any visible bubble is hidden — used
  /// during the in-world claw encounter so bubbles don't obscure the cabinet.
  bool get muted => _muted;
  set muted(bool value) {
    if (_muted == value) return;
    _muted = value;
    if (_muted) hide();
  }

  late ui.Paragraph _paragraph;

  // Max text width in native pixel-art pixels (before scale).
  static const double _maxTextWidth = 60;

  @override
  Future<void> onLoad() async {
    final image = await BubblePainter.generate();
    final sprite = Sprite(image);
    _box = NineTileBox.withGrid(
      sprite,
      leftWidth: BubblePainter.borderLeft.toDouble(),
      rightWidth: BubblePainter.borderRight.toDouble(),
      topHeight: BubblePainter.borderTop.toDouble(),
      bottomHeight: BubblePainter.borderBottom.toDouble(),
    );

    _paint = ui.Paint()..filterQuality = ui.FilterQuality.none;

    _buildParagraph('');
    _loaded = true;
  }

  void show(String text) {
    if (!_loaded || _muted) return;
    _text = text;
    _visible = true;
    _timer = _showDuration;
    _buildParagraph(text);
    _layout();
  }

  void hide() {
    _visible = false;
    _timer = 0;
  }

  void _buildParagraph(String text) {
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(fontSize: 5, fontFamily: _fontFamily),
          )
          ..pushStyle(ui.TextStyle(color: const ui.Color(0xFF3B2010)))
          ..addText(text);
    _paragraph = builder.build();
    _paragraph.layout(const ui.ParagraphConstraints(width: _maxTextWidth));
  }

  void _layout() {
    final textW = _paragraph.longestLine.ceilToDouble() + _padding * 2;
    final textH = _paragraph.height.ceilToDouble() + _padding * 2;

    // Ensure bubble is never smaller than the 9-slice source image.
    final minW = BubblePainter.width.toDouble();
    final minH = BubblePainter.height.toDouble();

    final boxW = (textW + BubblePainter.borderLeft + BubblePainter.borderRight)
        .clamp(minW, double.infinity);
    final boxH = (textH + BubblePainter.borderTop + BubblePainter.borderBottom)
        .clamp(minH, double.infinity);

    size = Vector2(boxW * _scale, boxH * _scale);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Track the follow — nudged right so the tail sits under its head.
    position = Vector2(
      follow.position.x + follow.size.x * 0.3,
      follow.position.y - size.y + follow.size.y * 0.1,
    );

    if (!_visible) return;
    _timer -= dt;
    if (_timer <= 0) {
      _visible = false;
    }
  }

  @override
  void render(ui.Canvas canvas) {
    if (!_visible || _text.isEmpty) return;

    // Draw at native pixel resolution, then scale up for crunch.
    canvas.save();
    canvas.scale(_scale);

    final nativeW = size.x / _scale;
    final nativeH = size.y / _scale;

    _box.drawRect(canvas, ui.Rect.fromLTWH(0, 0, nativeW, nativeH), _paint);

    canvas.drawParagraph(
      _paragraph,
      const ui.Offset(
        BubblePainter.borderLeft + _padding,
        BubblePainter.borderTop + _padding,
      ),
    );

    canvas.restore();
  }
}
