import 'dart:ui';

import 'package:flame/components.dart';
import '../lexaway_game.dart';
import '../world/biome_registry.dart';
import '../world/world_map.dart';

class _TerrainSprites {
  final Sprite surface;
  final Sprite fill;

  _TerrainSprites({required this.surface, required this.fill});
}

class _PierSprites {
  final Sprite leftCap;
  final Sprite centerA;
  final Sprite centerB;
  final Sprite centerC;
  final Sprite rightCap;
  final Sprite oceanSurface; // 16×6 wave detail at waterline
  final Sprite oceanFill; // 16×16 solid water for deep fill

  _PierSprites({
    required this.leftCap,
    required this.centerA,
    required this.centerB,
    required this.centerC,
    required this.rightCap,
    required this.oceanSurface,
    required this.oceanFill,
  });

  Sprite centerAt(int localTile) {
    switch (localTile % 3) {
      case 0:
        return centerA;
      case 1:
        return centerB;
      default:
        return centerC;
    }
  }
}

class Ground extends Component with HasGameReference<LexawayGame> {
  final WorldMap worldMap;

  double scrollOffset = 0;
  double _scrollSpeed = 0;

  Ground({required this.worldMap});

  final Map<BiomeType, _TerrainSprites> _sprites = {};
  _PierSprites? _pierSprites;
  late Paint _pixelPaint;
  late Paint _waterPaint;
  late Paint _oceanBasePaint;

  @override
  Future<void> onLoad() async {
    _pixelPaint = Paint()..filterQuality = FilterQuality.none;
    _waterPaint = Paint()
      ..filterQuality = FilterQuality.none
      ..color = const Color.fromARGB(140, 255, 255, 255);
    _oceanBasePaint = Paint()
      ..color = const Color.fromARGB(255, 0, 133, 248);

    final biomes = worldMap.segments.map((s) => s.biome).toSet();
    for (final biome in biomes) {
      await _loadBiomeSprites(biome);
    }
  }

  Future<void> _loadBiomeSprites(BiomeType biome) async {
    if (_sprites.containsKey(biome)) return;
    final def = BiomeRegistry.get(biome);
    final image = await game.images.load(def.terrainAsset);

    _sprites[biome] = _TerrainSprites(
      surface: Sprite(
        image,
        srcPosition: Vector2(def.surfaceSrcPosition[0], def.surfaceSrcPosition[1]),
        srcSize: Vector2.all(16),
      ),
      fill: Sprite(
        image,
        srcPosition: Vector2(def.fillSrcPosition[0], def.fillSrcPosition[1]),
        srcSize: Vector2.all(16),
      ),
    );

    if (biome == BiomeType.tropics && _pierSprites == null) {
      await _loadPierSprites();
    }
  }

  Future<void> _loadPierSprites() async {
    final image = await game.images.load('entities/tropics.png');
    Sprite col(double srcX, double srcY) => Sprite(
          image,
          srcPosition: Vector2(srcX, srcY),
          srcSize: Vector2(16, 32),
        );
    _pierSprites = _PierSprites(
      // Caps are shifted 3px inward to remove built-in padding from the
      // original entity sprite — puts the post flush with the ground edge.
      leftCap: col(179, 32),
      centerA: col(192, 32),
      centerB: col(208, 32),
      centerC: col(224, 32),
      rightCap: col(237, 32),
      // Ocean surface: just the 6px wave rows, rendered at the waterline.
      oceanSurface: Sprite(
        image,
        srcPosition: Vector2(192, 90),
        srcSize: Vector2(16, 6),
      ),
      // Ocean fill: solid blue for deep water.
      oceanFill: Sprite(
        image,
        srcPosition: Vector2(192, 96),
        srcSize: Vector2.all(16),
      ),
    );
  }

  Future<void> ensureBiomeLoaded(BiomeType biome) => _loadBiomeSprites(biome);

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
      final worldX = scrollOffset + x;
      final tileX = (worldX / tileSize).floor();
      final pierZone = worldMap.pierZoneAt(tileX);

      if (pierZone != null && _pierSprites != null) {
        _renderPierColumn(canvas, x, groundTop, tileSize, tileX, pierZone);
      } else {
        _renderTerrainColumn(canvas, x, groundTop, tileSize, worldX);
      }
    }
  }

  void _renderTerrainColumn(
    Canvas canvas,
    double x,
    double groundTop,
    double tileSize,
    double worldX,
  ) {
    final biome = worldMap.biomeAt(worldX);
    final terrain = _sprites[biome] ?? _sprites.values.first;

    terrain.surface.render(
      canvas,
      position: Vector2(x, groundTop),
      size: Vector2.all(tileSize),
      overridePaint: _pixelPaint,
    );

    var y = groundTop + tileSize;
    while (y < game.size.y) {
      terrain.fill.render(
        canvas,
        position: Vector2(x, y),
        size: Vector2.all(tileSize),
        overridePaint: _pixelPaint,
      );
      y += tileSize;
    }
  }

  void _renderPierColumn(
    Canvas canvas,
    double x,
    double groundTop,
    double tileSize,
    int tileX,
    PierZone zone,
  ) {
    final pier = _pierSprites!;
    final localTile = tileX - zone.startTile;
    final tileHeight = tileSize * 2;

    // Pick the right pier column sprite.
    final Sprite pierSprite;
    if (localTile == 0) {
      pierSprite = pier.leftCap;
    } else if (localTile == zone.widthTiles - 1) {
      pierSprite = pier.rightCap;
    } else {
      pierSprite = pier.centerAt(localTile - 1);
    }

    final waterTop = groundTop + tileSize * 0.6;
    final waveHeight = 6.0 * LexawayGame.pixelScale;

    // 0) Solid ocean-color rect behind everything — extends the parallax
    //    water layer's bottom edge color to the screen bottom.
    canvas.drawRect(
      Rect.fromLTRB(x, groundTop, x + tileSize, game.size.y),
      _oceanBasePaint,
    );

    // 1) Pier structure (deck + legs).
    pierSprite.render(
      canvas,
      position: Vector2(x, groundTop),
      size: Vector2(tileSize, tileHeight),
      overridePaint: _pixelPaint,
    );

    // 2) Semi-transparent wave surface at waterline.
    pier.oceanSurface.render(
      canvas,
      position: Vector2(x, waterTop),
      size: Vector2(tileSize, waveHeight),
      overridePaint: _waterPaint,
    );

    // 3) Semi-transparent ocean fill (bottom 16×16 of the ocean tile)
    //    repeated from below the waves to screen bottom — legs show through.
    var y = waterTop + waveHeight;
    while (y < game.size.y) {
      pier.oceanFill.render(
        canvas,
        position: Vector2(x, y),
        size: Vector2.all(tileSize),
        overridePaint: _waterPaint,
      );
      y += tileSize;
    }
  }
}
