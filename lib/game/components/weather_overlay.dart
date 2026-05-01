import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';

import '../events.dart';
import '../lexaway_game.dart';
import '../world/biome_registry.dart';
import '../world/weather_def.dart';
import '../world/world_map.dart';

/// Reusable "stuff falling from the sky" overlay. One instance handles every
/// biome — each biome's [WeatherDef] (or `null`) is read from the registry
/// and the active def swaps when the player crosses biome boundaries.
///
/// Renders a flat particle pool with `canvas.drawImageRect` from a single
/// preloaded atlas (one per biome), matching [WindLines]'s custom-render
/// approach. No per-particle component overhead.
///
/// Frames cycle on a single shared timer. Each particle gets a random
/// `frameOffset` so the population reads as desynced twinkle instead of
/// pulsing in unison.
class WeatherOverlay extends Component with HasGameReference<LexawayGame> {
  /// Picked from saved scroll so the right biome is active on cold start.
  final double initialScrollOffset;

  WeatherOverlay({this.initialScrollOffset = 0});

  /// 0.6s gives a snappy fade. `BiomeChanged` fires at *screen center*
  /// crossing (see `ScrollController.update`), so by the time we react the
  /// right half of the screen is already in the new biome — a slow fade
  /// would leave us still ramping in well past the boundary.
  static const double _fadeDuration = 0.6;

  static final _rng = Random();

  final Map<BiomeType, ui.Image> _atlases = {};
  final List<_Particle> _particles = [];
  final ui.Paint _paint = ui.Paint()..filterQuality = ui.FilterQuality.none;

  WeatherDef? _activeDef;
  ui.Image? _activeImage;
  double _currentOpacity = 0;
  double _targetOpacity = 0;
  double _frameTimer = 0;
  int _sharedFrame = 0;
  double _driftClock = 0;

  StreamSubscription<GameEvent>? _sub;

  @override
  Future<void> onLoad() async {
    // Preload atlases for every biome already in the world. Streamer-added
    // biomes are loaded lazily via [ensureBiomeLoaded] from `_loadNewBiomes`.
    final biomes = game.worldMap.segments.map((s) => s.biome).toSet();
    for (final biome in biomes) {
      await _loadAtlas(biome);
    }

    final initialBiome = game.worldMap.biomeAt(initialScrollOffset);
    final def = BiomeRegistry.get(initialBiome).weather;
    if (def != null) {
      _activate(def, _atlases[initialBiome]);
      _seedPrewarmed();
      // Cold-start with weather visible immediately — skip the fade.
      _currentOpacity = 1;
    }

    _sub = game.events.on<BiomeChanged>().listen(_onBiomeChanged);
  }

  Future<void> ensureBiomeLoaded(BiomeType biome) => _loadAtlas(biome);

  Future<void> _loadAtlas(BiomeType biome) async {
    if (_atlases.containsKey(biome)) return;
    final def = BiomeRegistry.get(biome).weather;
    if (def == null) return;
    _atlases[biome] = await game.images.load(def.spritePath);
  }

  void _onBiomeChanged(BiomeChanged event) {
    final def = BiomeRegistry.get(event.current).weather;
    if (def == null) {
      // Fading out — keep current particles but stop spawning new defs.
      _targetOpacity = 0;
      return;
    }
    if (def == _activeDef) {
      _targetOpacity = 1;
      return;
    }
    // Swap def. With only one weather biome shipping today, this branch
    // really only fires on no-weather → weather transitions; A → B re-seeds
    // hard, which is fine until we ship a second weather biome.
    _activate(def, _atlases[event.current]);
    if (_currentOpacity == 0) _seedAboveScreen();
    _targetOpacity = 1;
  }

  void _activate(WeatherDef def, ui.Image? image) {
    _activeDef = def;
    _activeImage = image;
    _resizePool(def.particleCount);
  }

  void _resizePool(int count) {
    if (_particles.length == count) return;
    if (_particles.length > count) {
      _particles.removeRange(count, _particles.length);
    } else {
      while (_particles.length < count) {
        _particles.add(_Particle());
      }
    }
  }

  /// Seed particles with random Y across the full screen — used on cold
  /// start so winter is already snowing on the first frame.
  void _seedPrewarmed() {
    final size = game.size;
    for (final p in _particles) {
      _respawn(p, size, fullHeight: true);
    }
  }

  /// Seed particles just above the screen — used when fading in mid-game,
  /// so flakes drift down into view rather than appearing in place.
  void _seedAboveScreen() {
    final size = game.size;
    for (final p in _particles) {
      _respawn(p, size, fullHeight: false);
    }
  }

  void _respawn(_Particle p, Vector2 size, {required bool fullHeight}) {
    final def = _activeDef!;
    p.x = _rng.nextDouble() * size.x;
    if (fullHeight) {
      p.y = _rng.nextDouble() * size.y;
    } else {
      // Stagger above the top edge so they don't all enter at the same instant.
      p.y = -_rng.nextDouble() * size.y * 0.5 - def.frameHeight * def.scale;
    }
    p.fallSpeed = def.minFallSpeed +
        _rng.nextDouble() * (def.maxFallSpeed - def.minFallSpeed);
    p.drift = def.driftAmplitude * (0.5 + _rng.nextDouble() * 0.5);
    p.phase = _rng.nextDouble() * pi * 2;
    p.opacity = def.minOpacity +
        _rng.nextDouble() * (def.maxOpacity - def.minOpacity);
    p.frameOffset = _rng.nextInt(def.frameCount);
  }

  @override
  void update(double dt) {
    // Tick opacity toward target.
    if (_currentOpacity != _targetOpacity) {
      final step = dt / _fadeDuration;
      if (_currentOpacity < _targetOpacity) {
        _currentOpacity = (_currentOpacity + step).clamp(0.0, 1.0);
      } else {
        _currentOpacity = (_currentOpacity - step).clamp(0.0, 1.0);
      }
    }

    // Nothing to update if there's no active def or we've fully faded out.
    if (_activeDef == null || (_currentOpacity == 0 && _targetOpacity == 0)) {
      return;
    }

    final def = _activeDef!;
    final scale = LexawayGame.pixelScale;
    final size = game.size;
    final spriteH = def.frameHeight * def.scale * scale;

    _driftClock += dt;
    _frameTimer += dt;
    if (_frameTimer >= def.frameDuration) {
      final advance = (_frameTimer / def.frameDuration).floor();
      _sharedFrame = (_sharedFrame + advance) % def.frameCount;
      _frameTimer -= advance * def.frameDuration;
    }

    for (final p in _particles) {
      p.y += p.fallSpeed * scale * dt;
      // Pure sin-wave horizontal sway. Multiplied by dt so amplitude reads as
      // px/sec at peak — feels gentle at small values.
      p.x += sin(_driftClock * def.driftFrequency + p.phase) * p.drift * dt;

      if (p.y > size.y) {
        _respawn(p, size, fullHeight: false);
      }

      // Wrap horizontally so wind-blown flakes don't permanently leave the screen.
      if (p.x < -spriteH) {
        p.x += size.x + spriteH * 2;
      } else if (p.x > size.x + spriteH) {
        p.x -= size.x + spriteH * 2;
      }
    }
  }

  @override
  void render(ui.Canvas canvas) {
    if (_activeDef == null || _activeImage == null || _currentOpacity <= 0) {
      return;
    }
    final def = _activeDef!;
    final image = _activeImage!;
    final scale = LexawayGame.pixelScale;
    final spriteW = def.frameWidth * def.scale * scale;
    final spriteH = def.frameHeight * def.scale * scale;

    for (final p in _particles) {
      final frame = (p.frameOffset + _sharedFrame) % def.frameCount;
      final src = ui.Rect.fromLTWH(
        frame * def.frameWidth,
        0,
        def.frameWidth,
        def.frameHeight,
      );
      // Snap to pixel grid so the art reads crisp at integer scale.
      final px = (p.x / scale).round() * scale;
      final py = (p.y / scale).round() * scale;
      final dst = ui.Rect.fromLTWH(px, py, spriteW, spriteH);
      final alpha = (p.opacity * _currentOpacity * 255).round();
      _paint.color = ui.Color.fromARGB(alpha, 255, 255, 255);
      canvas.drawImageRect(image, src, dst, _paint);
    }
  }

  @override
  void onRemove() {
    _sub?.cancel();
    super.onRemove();
  }
}

class _Particle {
  double x = 0;
  double y = 0;
  double fallSpeed = 0;
  double drift = 0;
  double phase = 0;
  double opacity = 1;
  int frameOffset = 0;
}
