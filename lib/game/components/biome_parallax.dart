import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/parallax.dart';

import '../lexaway_game.dart';
import '../world/biome_registry.dart';
import '../world/world_map.dart';

/// Per-biome parallax backgrounds with crossfade transitions.
///
/// Holds preloaded [Parallax] keyed by [BiomeType], crossfading over
/// [_fadeDuration]. Outside transitions the active parallax renders directly,
/// avoiding saveLayer overhead.
class BiomeParallax extends PositionComponent
    with HasGameReference<LexawayGame> {
  static const double _fadeDuration = 1.5;

  /// Scroll position for picking the starting biome, from saved state so the
  /// parallax matches the player's actual location, not the first segment.
  final double initialScrollOffset;

  final WorldMap worldMap;

  BiomeParallax({required this.worldMap, this.initialScrollOffset = 0});

  final Map<BiomeType, Parallax> _cache = {};
  final Paint _fadePaint = Paint();

  Parallax? _active;
  Parallax? _outgoing;
  double _fadeTimer = 0;

  bool get _isFading => _outgoing != null;

  @override
  Future<void> onLoad() async {
    final biomes = worldMap.segments.map((s) => s.biome).toSet();
    for (final biome in biomes) {
      await _loadBiome(biome);
    }
    final initialBiome = worldMap.biomeAt(initialScrollOffset);
    _active = _cache[initialBiome];
  }

  Future<void> _loadBiome(BiomeType biome) async {
    if (_cache.containsKey(biome)) return;
    final def = BiomeRegistry.get(biome);
    final parallax = await Parallax.load(
      def.parallaxLayers.map(ParallaxImageData.new).toList(),
      size: size,
      baseVelocity: Vector2.zero(),
      velocityMultiplierDelta: Vector2(1.4, 0),
      images: game.images,
      filterQuality: FilterQuality.none,
    );
    _cache[biome] = parallax;
  }

  Future<void> ensureBiomeLoaded(BiomeType biome) => _loadBiome(biome);

  /// Begin crossfading to a new biome's parallax.
  void transitionTo(BiomeType biome) {
    final next = _cache[biome];
    if (next == null || next == _active) return;

    // If already mid-fade, snap to completion first.
    if (_isFading) {
      _outgoing = null;
    }

    // Carry scroll velocity so the new parallax moves in sync.
    if (_active != null) {
      next.baseVelocity.setFrom(_active!.baseVelocity);
    }

    _outgoing = _active;
    _active = next;
    _fadeTimer = 0;
  }

  void setBaseVelocity(Vector2 velocity) {
    _active?.baseVelocity.setFrom(velocity);
    _outgoing?.baseVelocity.setFrom(velocity);
  }

  /// Apply gentle cloud drift to layers 1 & 2 of all live parallaxes.
  void applyCloudDrift(double dt) {
    _driftLayers(_active, dt);
    if (_isFading) _driftLayers(_outgoing, dt);
  }

  void _driftLayers(Parallax? p, double dt) {
    if (p == null) return;
    final layers = p.layers;
    if (layers.length > 1) {
      layers[1].update(Vector2(LexawayGame.cloudDrift * dt, 0), dt);
    }
    if (layers.length > 2) {
      layers[2].update(Vector2(LexawayGame.cloudDrift * 1.8 * dt, 0), dt);
    }
  }

  @override
  void update(double dt) {
    _active?.update(dt);
    _outgoing?.update(dt);

    if (_isFading) {
      _fadeTimer += dt;
      if (_fadeTimer >= _fadeDuration) {
        _outgoing = null;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (!_isFading) {
      // Fast path — no saveLayer needed.
      _active?.render(canvas);
      return;
    }

    final t = (_fadeTimer / _fadeDuration).clamp(0.0, 1.0);
    final outAlpha = ((1.0 - t) * 255).round();
    final inAlpha = (t * 255).round();
    final bounds = Offset.zero & Size(size.x, size.y);

    if (_outgoing != null && outAlpha > 0) {
      _fadePaint.color = Color.fromARGB(outAlpha, 255, 255, 255);
      canvas.saveLayer(bounds, _fadePaint);
      _outgoing!.render(canvas);
      canvas.restore();
    }

    if (_active != null && inAlpha > 0) {
      _fadePaint.color = Color.fromARGB(inAlpha, 255, 255, 255);
      canvas.saveLayer(bounds, _fadePaint);
      _active!.render(canvas);
      canvas.restore();
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Recalculate the parallax height from the new game dimensions, matching
    // the formula in LexawayGame.onLoad.
    final parallaxHeight = size.y * LexawayGame.groundLevel +
        16 * LexawayGame.pixelScale -
        40;
    final componentSize = Vector2(size.x, parallaxHeight);
    super.size.setFrom(componentSize);
    for (final p in _cache.values) {
      p.resize(componentSize);
    }
  }
}
