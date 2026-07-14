import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import '../lexaway_game.dart';

/// Horizontal speed streaks that appear while the dino is running.
class WindLines extends Component with HasGameReference<LexawayGame> {
  static const int _maxLines = 12;
  static const double _spawnInterval = 0.06;
  static const double _lineSpeed = 320.0;
  static const double _minWidth = 6.0;
  static const double _maxWidth = 14.0;
  static const double _lineHeight = 1.0; // 1 pixel tall at pixel scale

  static final _rng = Random();

  final List<_WindLine> _lines = [];
  double _spawnTimer = 0;
  bool _active = false;
  double _fadeOpacity = 0;

  final Paint _paint = Paint()..color = const Color(0xFFFFFFFF);

  void start() => _active = true;

  void stop() => _active = false;

  @override
  void update(double dt) {
    final step = dt.clamp(0, 1);
    final scale = LexawayGame.pixelScale;

    if (_active && _fadeOpacity < 1) {
      _fadeOpacity = (_fadeOpacity + step * 4).clamp(0, 1);
    } else if (!_active && _fadeOpacity > 0) {
      _fadeOpacity = (_fadeOpacity - step * 3).clamp(0, 1);
    }

    if (_fadeOpacity <= 0 && _lines.isEmpty) return;

    if (_active) {
      _spawnTimer += step;
      while (_spawnTimer >= _spawnInterval) {
        _spawnTimer -= _spawnInterval;
        if (_lines.length < _maxLines) {
          _lines.add(_spawn(scale));
        }
      }
    }

    for (var i = _lines.length - 1; i >= 0; i--) {
      _lines[i].x -= _lineSpeed * scale * step;
      if (_lines[i].x + _lines[i].width < 0) {
        _lines.removeAt(i);
      }
    }
  }

  _WindLine _spawn(double scale) {
    final groundTop = game.size.y * LexawayGame.groundLevel;
    // keep above ground
    final y = 20 + _rng.nextDouble() * (groundTop - 40);
    final w = (_minWidth + _rng.nextDouble() * (_maxWidth - _minWidth)) * scale;
    final x = game.size.x + _rng.nextDouble() * 40;
    final opacity = 0.3 + _rng.nextDouble() * 0.4;
    return _WindLine(x: x, y: y, width: w, opacity: opacity);
  }

  @override
  void render(Canvas canvas) {
    if (_fadeOpacity <= 0 && _lines.isEmpty) return;
    final scale = LexawayGame.pixelScale;
    final h = _lineHeight * scale;

    for (final line in _lines) {
      final alpha = (line.opacity * _fadeOpacity * 255).round();
      _paint.color = Color.fromARGB(alpha, 255, 255, 255);
      final px = (line.x / scale).round() * scale;
      final py = (line.y / scale).round() * scale;
      canvas.drawRect(Rect.fromLTWH(px, py, line.width, h), _paint);
    }
  }
}

class _WindLine {
  double x;
  double y;
  double width;
  double opacity;

  _WindLine({
    required this.x,
    required this.y,
    required this.width,
    required this.opacity,
  });
}
