import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../game/lexaway_game.dart';
import '../game/world/world_map.dart';

/// Biome colors for the mini-map track.
/// Use a loud fallback so missing entries are obvious during development.
const _biomeColors = {
  BiomeType.grassland: Color(0xFF4a8c3f),
  BiomeType.winter: Color(0xFFc7e6f2),
};
const _missingBiomeColor = Color(0xFFff00ff); // magenta = "you forgot one"

/// How many tiles of world to show in the mini-map window.
const _windowTiles = 100;
const _windowPx = _windowTiles * 16.0 * LexawayGame.pixelScale;

/// A pixel-art style mini-map painted inside the banner.
/// Shows a windowed track around the player with biome coloring and a marker.
class MiniMap extends StatelessWidget {
  final WorldMap worldMap;
  final ValueListenable<double> scrollOffset;

  const MiniMap({super.key, required this.worldMap, required this.scrollOffset});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MiniMapPainter(
        worldMap: worldMap,
        scrollOffset: scrollOffset,
      ),
      size: const Size(double.infinity, 12),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  final WorldMap worldMap;
  final ValueListenable<double> scrollOffset;

  _MiniMapPainter({required this.worldMap, required this.scrollOffset})
      : super(repaint: scrollOffset);

  @override
  void paint(Canvas canvas, Size size) {
    if (worldMap.segments.isEmpty) return;

    final totalPx = worldMap.totalLengthPx;
    if (totalPx <= 0) return;

    // Window: player at 1/3 from the left, showing _windowPx of world.
    final offset = scrollOffset.value;
    final windowStart = max(0.0, offset - _windowPx / 3);
    final windowEnd = min(totalPx, windowStart + _windowPx);
    final windowLen = windowEnd - windowStart;
    if (windowLen <= 0) return;

    final trackHeight = 6.0;
    final trackY = (size.height - trackHeight) / 2;
    final trackRadius = Radius.circular(trackHeight / 2);

    // Dark track background
    final bgPaint = Paint()..color = const Color(0xFF1a1a2e);
    canvas.drawRRect(
      RRect.fromLTRBR(0, trackY, size.width, trackY + trackHeight, trackRadius),
      bgPaint,
    );

    // Biome-colored segments (only those overlapping the window)
    for (final seg in worldMap.segments) {
      if (seg.endPx <= windowStart || seg.startPx >= windowEnd) continue;
      final x1 = ((seg.startPx - windowStart) / windowLen * size.width)
          .clamp(0.0, size.width);
      final x2 = ((seg.endPx - windowStart) / windowLen * size.width)
          .clamp(0.0, size.width);

      final color = _biomeColors[seg.biome] ?? _missingBiomeColor;
      final segPaint = Paint()..color = color;

      canvas.drawRRect(
        RRect.fromLTRBR(
          x1, trackY, x2, trackY + trackHeight, trackRadius,
        ),
        segPaint,
      );
    }

    // Player marker
    final markerX = ((offset - windowStart) / windowLen * size.width)
        .clamp(0.0, size.width);
    final markerSize = 8.0;

    // Diamond shape
    final markerPath = Path()
      ..moveTo(markerX, trackY - 1)
      ..lineTo(markerX + markerSize / 2, trackY + trackHeight / 2)
      ..lineTo(markerX, trackY + trackHeight + 1)
      ..lineTo(markerX - markerSize / 2, trackY + trackHeight / 2)
      ..close();

    // Shadow
    final shadowPaint = Paint()..color = const Color(0x40000000);
    canvas.drawPath(markerPath.shift(const Offset(0, 1)), shadowPaint);

    // Fill
    final markerPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(markerX, trackY - 1),
        Offset(markerX, trackY + trackHeight + 1),
        [const Color(0xFFffd700), const Color(0xFFe6a800)],
      );
    canvas.drawPath(markerPath, markerPaint);

    // Outline
    final outlinePaint = Paint()
      ..color = const Color(0xFF8b6914)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(markerPath, outlinePaint);
  }

  @override
  bool shouldRepaint(_MiniMapPainter oldDelegate) =>
      oldDelegate.worldMap != worldMap;
}
