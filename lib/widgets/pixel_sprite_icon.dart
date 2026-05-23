import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pixel-art icon backed by a horizontal sprite sheet of square frames.
///
/// Frame 0 is the idle visual; the last frame is the fully-pressed visual.
/// On press-down we snap to the pressed frame; on release we step back to
/// idle one frame at a time for a brief "release" animation.
///
/// Pointer state is observed via [Listener], which does not claim the gesture
/// arena — the surrounding [IconButton] still handles the tap.
class PixelSpriteIcon extends StatefulWidget {
  const PixelSpriteIcon({
    super.key,
    required this.asset,
    required this.frameSize,
    this.frameCount = 4,
    this.scale = 2,
  });

  final String asset;
  final double frameSize;
  final int frameCount;
  final double scale;

  @override
  State<PixelSpriteIcon> createState() => _PixelSpriteIconState();
}

class _PixelSpriteIconState extends State<PixelSpriteIcon> {
  ui.Image? _sheet;
  int _frame = 0;
  Timer? _releaseTimer;

  @override
  void initState() {
    super.initState();
    _SpriteSheetCache.load(widget.asset).then((img) {
      if (mounted) setState(() => _sheet = img);
    });
  }

  @override
  void dispose() {
    _releaseTimer?.cancel();
    super.dispose();
  }

  void _press() {
    _releaseTimer?.cancel();
    setState(() => _frame = widget.frameCount - 1);
  }

  void _release() {
    _releaseTimer?.cancel();
    _releaseTimer = Timer.periodic(const Duration(milliseconds: 28), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_frame <= 0) {
        t.cancel();
        return;
      }
      setState(() => _frame -= 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.frameSize * widget.scale;
    return Listener(
      onPointerDown: (_) => _press(),
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: SizedBox(
        width: size,
        height: size,
        child: _sheet == null
            ? null
            : CustomPaint(
                painter: _SpritePainter(
                  sheet: _sheet!,
                  frameIndex: _frame,
                  frameSize: widget.frameSize,
                ),
              ),
      ),
    );
  }
}

class _SpritePainter extends CustomPainter {
  _SpritePainter({
    required this.sheet,
    required this.frameIndex,
    required this.frameSize,
  });

  final ui.Image sheet;
  final int frameIndex;
  final double frameSize;

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
      frameIndex * frameSize,
      0,
      frameSize,
      frameSize,
    );
    final dst = Offset.zero & size;
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    canvas.drawImageRect(sheet, src, dst, paint);
  }

  @override
  bool shouldRepaint(_SpritePainter old) =>
      old.sheet != sheet ||
      old.frameIndex != frameIndex ||
      old.frameSize != frameSize;
}

class _SpriteSheetCache {
  static final Map<String, ui.Image> _cache = {};
  static final Map<String, Future<ui.Image>> _pending = {};

  static Future<ui.Image> load(String asset) {
    final cached = _cache[asset];
    if (cached != null) return Future.value(cached);
    return _pending.putIfAbsent(asset, () async {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _cache[asset] = frame.image;
      _pending.remove(asset);
      return frame.image;
    });
  }
}
