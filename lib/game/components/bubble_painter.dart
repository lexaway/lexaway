import 'dart:ui';

/// Where the tail points from the bubble.
enum TailDirection { bottomLeft, bottomCenter, bottomRight }

/// Generates tiny pixel-art speech bubble images at native resolution
/// (no upscaling — Flame renders them with FilterQuality.none for crunch).
///
/// The generated image is suitable for Flame's NineTileBoxComponent.
class BubblePainter {
  /// Width/height of the bubble image (before 9-slice stretching).
  static const int width = 22;
  static const int height = 18;

  /// 9-slice border insets (left, top, right, bottom).
  /// The stretchable center is everything between these.
  static const int borderLeft = 4;
  static const int borderTop = 4;
  static const int borderRight = 4;
  static const int borderBottom = 7; // extra room for the tail

  /// Tail size in pixels.
  static const int tailWidth = 5;
  static const int tailHeight = 4;

  static Future<Image> generate({
    Color fill = const Color(0xFFF5E6C8),
    Color border = const Color(0xFF5C3A1E),
    TailDirection tail = TailDirection.bottomLeft,
  }) async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    final fillPaint = Paint()..color = fill;
    final borderPaint = Paint()..color = border;

    // Body rect (leaving room for tail below).
    const bodyLeft = 0;
    const bodyTop = 0;
    const bodyRight = width;
    const bodyBottom = height - tailHeight;

    // --- Border (drawn first, 1px thick) ---
    // Top edge (with 1px chamfer at corners)
    _hLine(canvas, borderPaint, bodyLeft + 1, bodyTop, bodyRight - 1);
    // Bottom edge
    _hLine(canvas, borderPaint, bodyLeft + 1, bodyBottom - 1, bodyRight - 1);
    // Left edge
    _vLine(canvas, borderPaint, bodyLeft, bodyTop + 1, bodyBottom - 1);
    // Right edge
    _vLine(canvas, borderPaint, bodyRight - 1, bodyTop + 1, bodyBottom - 1);

    // --- Fill ---
    // Main fill (inset by 1px from border)
    canvas.drawRect(
      Rect.fromLTRB(
        (bodyLeft + 1).toDouble(),
        (bodyTop + 1).toDouble(),
        (bodyRight - 1).toDouble(),
        (bodyBottom - 1).toDouble(),
      ),
      fillPaint,
    );

    // --- Tail ---
    final tailX = switch (tail) {
      TailDirection.bottomLeft => bodyLeft + 3,
      TailDirection.bottomCenter => (bodyRight ~/ 2) - (tailWidth ~/ 2),
      TailDirection.bottomRight => bodyRight - 3 - tailWidth,
    };
    _drawTail(canvas, fillPaint, borderPaint, tailX, bodyBottom - 1);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    return image;
  }

  static void _drawTail(Canvas canvas, Paint fill, Paint border, int x, int y) {
    // Draw a small triangular tail pointing down.
    // Row by row, narrowing as it goes:
    //
    //  XFFFFX    (y+0: border left, fill, border right — connects to body)
    //   XFFX     (y+1)
    //    XX       (y+2)
    //    X        (y+3: tip)

    // Row 0: full width fill (already part of body), just add border sides
    _pixel(canvas, border, x, y);
    for (var i = 1; i < tailWidth - 1; i++) {
      _pixel(canvas, fill, x + i, y);
    }
    _pixel(canvas, border, x + tailWidth - 1, y);

    // Row 1
    _pixel(canvas, border, x + 1, y + 1);
    for (var i = 2; i < tailWidth - 2; i++) {
      _pixel(canvas, fill, x + i, y + 1);
    }
    _pixel(canvas, border, x + tailWidth - 2, y + 1);

    // Row 2
    _pixel(canvas, border, x + 2, y + 2);
    _pixel(canvas, border, x + tailWidth - 3, y + 2);

    // Row 3: tip
    _pixel(canvas, border, x + 2, y + 3);
  }

  static void _pixel(Canvas canvas, Paint paint, int x, int y) {
    canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1), paint);
  }

  static void _hLine(Canvas canvas, Paint paint, int x1, int y, int x2) {
    canvas.drawRect(
      Rect.fromLTRB(x1.toDouble(), y.toDouble(), x2.toDouble(), y + 1.0),
      paint,
    );
  }

  static void _vLine(Canvas canvas, Paint paint, int x, int y1, int y2) {
    canvas.drawRect(
      Rect.fromLTRB(x.toDouble(), y1.toDouble(), x + 1.0, y2.toDouble()),
      paint,
    );
  }
}
