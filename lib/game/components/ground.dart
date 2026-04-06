import 'dart:ui';

import 'package:flame/components.dart';
import '../lexaway_game.dart';
import '../persistable.dart';

class Ground extends Component with HasGameReference<LexawayGame>, Persistable {
  double scrollOffset = 0;
  double _scrollSpeed = 0;

  @override
  String get saveKey => 'ground';

  @override
  Map<String, dynamic> saveState() => {'offset': scrollOffset};

  @override
  void restoreState(Map<String, dynamic> state) {
    scrollOffset = (state['offset'] as num).toDouble();
  }

  late Sprite _grassSprite;
  late Sprite _dirtSprite;
  late Paint _pixelPaint;

  @override
  Future<void> onLoad() async {
    final image = await game.images.load('terrain/grassland.png');

    // Grass surface tile (r1_c4)
    _grassSprite = Sprite(
      image,
      srcPosition: Vector2(64, 16),
      srcSize: Vector2.all(16),
    );

    // Dirt fill tile (r3_c4)
    _dirtSprite = Sprite(
      image,
      srcPosition: Vector2(64, 48),
      srcSize: Vector2.all(16),
    );

    _pixelPaint = Paint()..filterQuality = FilterQuality.none;
  }

  void startScrolling(double speed) => _scrollSpeed = speed;
  void stopScrolling() => _scrollSpeed = 0;

  @override
  void update(double dt) {
    scrollOffset += _scrollSpeed * dt;
  }

  @override
  void render(Canvas canvas) {
    final tileSize = 16.0 * LexawayGame.pixelScale;
    final groundTop = game.size.y * LexawayGame.groundLevel;
    final tilesAcross = (game.size.x / tileSize).ceil() + 2;
    final pixelOffset = scrollOffset % tileSize;

    for (int i = 0; i < tilesAcross; i++) {
      final x = i * tileSize - pixelOffset;

      // Grass surface row
      _grassSprite.render(
        canvas,
        position: Vector2(x, groundTop),
        size: Vector2.all(tileSize),
        overridePaint: _pixelPaint,
      );

      // Dirt rows below, fill to bottom of screen
      var y = groundTop + tileSize;
      while (y < game.size.y) {
        _dirtSprite.render(
          canvas,
          position: Vector2(x, y),
          size: Vector2.all(tileSize),
          overridePaint: _pixelPaint,
        );
        y += tileSize;
      }
    }
  }
}
