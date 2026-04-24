import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import '../lexaway_game.dart';
import '../world/biome_registry.dart';
import '../world/world_map.dart';

class _TerrainSprites {
  final Sprite surface;
  final Sprite fill;
  final Sprite surfaceLeft;
  final Sprite surfaceRight;
  final Sprite fillLeft;
  final Sprite fillRight;

  _TerrainSprites({
    required this.surface,
    required this.fill,
    required this.surfaceLeft,
    required this.surfaceRight,
    required this.fillLeft,
    required this.fillRight,
  });
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

  final ValueNotifier<double> scrollNotifier = ValueNotifier(0.0);
  double get scrollOffset => scrollNotifier.value;
  set scrollOffset(double v) => scrollNotifier.value = v;

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
    // Pier sprites are needed whenever any segment declares pier zones,
    // regardless of biome. Keeping this decoupled from the tropics biome
    // check means future biomes that host piers won't silently fall back
    // to sky-reveal rendering because tropics assets never loaded.
    if (worldMap.segments.any((s) => s.pierZones.isNotEmpty)) {
      await _loadPierSprites();
    }
  }

  Future<void> _loadBiomeSprites(BiomeType biome) async {
    if (_sprites.containsKey(biome)) return;
    final def = BiomeRegistry.get(biome);
    final image = await game.images.load(def.terrainAsset);

    final sx = def.surfaceSrcPosition[0];
    final sy = def.surfaceSrcPosition[1];
    Sprite tile(double x, double y) =>
        Sprite(image, srcPosition: Vector2(x, y), srcSize: Vector2.all(16));

    _sprites[biome] = _TerrainSprites(
      surface: tile(sx, sy),
      fill: tile(def.fillSrcPosition[0], def.fillSrcPosition[1]),
      surfaceLeft: tile(sx - 16, sy),
      surfaceRight: tile(sx + 16, sy),
      fillLeft: tile(sx - 16, sy + 16),
      fillRight: tile(sx + 16, sy + 16),
    );
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

  Future<void> ensureBiomeLoaded(BiomeType biome) async {
    await _loadBiomeSprites(biome);
    // Streamed-in segments may introduce the first pier in the world;
    // don't rely on the initial onLoad() pass having seen one.
    if (_pierSprites == null &&
        worldMap.segments.any((s) => s.pierZones.isNotEmpty)) {
      await _loadPierSprites();
    }
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
      final worldX = scrollOffset + x;
      final tileX = (worldX / tileSize).floor();
      final pierZone = worldMap.pierZoneAt(tileX);

      if (pierZone != null && _pierSprites != null) {
        _renderPierColumn(canvas, x, groundTop, tileSize, tileX, pierZone);
      } else {
        _renderTerrainColumn(canvas, x, groundTop, tileSize, worldX, tileX);
      }
    }
  }

  void _renderTerrainColumn(
    Canvas canvas,
    double x,
    double groundTop,
    double tileSize,
    double worldX,
    int tileX,
  ) {
    final biome = worldMap.biomeAt(worldX);
    final terrain = _sprites[biome] ?? _sprites.values.first;

    // Check if we're on the edge next to a pier. `PierZone.endTile` is
    // exclusive (see `widthTiles = endTile - startTile`), so the last tile
    // actually inside a pier is `endTile - 1` and the terrain tile just
    // right of the pier is at `endTile`.
    final pierRight = worldMap.pierZoneAt(tileX + 1);
    final pierLeft = worldMap.pierZoneAt(tileX - 1);
    final adjacentToPier = (pierRight != null && tileX + 1 == pierRight.startTile)
        || (pierLeft != null && tileX - 1 == pierLeft.endTile - 1);

    final Sprite surfaceSprite;
    final Sprite fillSprite;
    if (pierRight != null && tileX + 1 == pierRight.startTile) {
      surfaceSprite = terrain.surfaceRight;
      fillSprite = terrain.fillRight;
    } else if (pierLeft != null && tileX - 1 == pierLeft.endTile - 1) {
      surfaceSprite = terrain.surfaceLeft;
      fillSprite = terrain.fillLeft;
    } else {
      surfaceSprite = terrain.surface;
      fillSprite = terrain.fill;
    }

    // Paint the full ocean stack behind the edge column so any transparent
    // pixels in the edge sprite reveal waves + tinted fill (not flat blue),
    // matching the pier columns next door. The terrain's opaque pixels
    // cover the water above the visible gap.
    if (adjacentToPier && _pierSprites != null) {
      _renderOceanBase(canvas, x, groundTop, tileSize);
      _renderOceanSurface(canvas, x, groundTop, tileSize);
    }

    surfaceSprite.render(
      canvas,
      position: Vector2(x, groundTop),
      size: Vector2.all(tileSize),
      overridePaint: _pixelPaint,
    );

    var y = groundTop + tileSize;
    while (y < game.size.y) {
      fillSprite.render(
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

    _renderOceanBase(canvas, x, groundTop, tileSize);

    // Pier structure (deck + legs) sits on top of the solid ocean base,
    // then waves + semi-transparent fill go in front so the legs look
    // submerged.
    pierSprite.render(
      canvas,
      position: Vector2(x, groundTop),
      size: Vector2(tileSize, tileHeight),
      overridePaint: _pixelPaint,
    );

    _renderOceanSurface(canvas, x, groundTop, tileSize);
  }

  /// Solid ocean-color rect extending from the waterline to the screen
  /// bottom. Drawn behind pier legs (so they get tinted by the subsequent
  /// semi-transparent waves) and also behind the terrain edge column that
  /// butts against a pier (so transparent pixels in the edge sprite reveal
  /// water instead of sky).
  void _renderOceanBase(
    Canvas canvas,
    double x,
    double groundTop,
    double tileSize,
  ) {
    canvas.drawRect(
      Rect.fromLTRB(x, groundTop, x + tileSize, game.size.y),
      _oceanBasePaint,
    );
  }

  /// Semi-transparent wave strip at the waterline plus the tinted fill
  /// repeating down to screen bottom. Rendered on top of the pier so the
  /// legs look submerged.
  void _renderOceanSurface(
    Canvas canvas,
    double x,
    double groundTop,
    double tileSize,
  ) {
    final pier = _pierSprites!;
    final waterTop = groundTop + tileSize * 0.6;
    final waveHeight = 6.0 * LexawayGame.pixelScale;

    pier.oceanSurface.render(
      canvas,
      position: Vector2(x, waterTop),
      size: Vector2(tileSize, waveHeight),
      overridePaint: _waterPaint,
    );

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
