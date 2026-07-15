import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';

import '../events.dart';
import '../lexaway_game.dart';
import '../world/biome_registry.dart';
import '../world/noise.dart';
import '../world/weather_def.dart';
import '../world/world_map.dart';
import 'world_camera.dart';

/// Reusable "stuff falling from the sky" overlay. One instance handles every
/// biome; the active [WeatherDef] (or `null`) is read from the registry and
/// swaps at biome boundaries.
///
/// Flat particle pool rendered via `canvas.drawImageRect` from a per-biome
/// atlas (like [WindLines]) — no per-particle component overhead.
///
/// Frames cycle on one shared timer; each particle's random `frameOffset`
/// desyncs the twinkle so the population doesn't pulse in unison.
class WeatherOverlay extends Component with HasGameReference<LexawayGame> {
  /// Picked from saved scroll so the right biome is active on cold start.
  final double initialScrollOffset;

  final WorldMap worldMap;
  final WorldCamera camera;
  final GameEvents _events;

  WeatherOverlay({
    required this.worldMap,
    required this.camera,
    required GameEvents events,
    this.initialScrollOffset = 0,
  }) : _events = events;

  /// Snappy fade. `BiomeChanged` fires at *screen-center* crossing (see
  /// `WorldScrollController.update`), so the right half is already in the new
  /// biome; a slow fade would still be ramping well past the boundary.
  static const double _fadeDuration = 0.6;

  static final _rng = Random();

  final Map<BiomeType, ui.Image> _atlases = {};
  final List<_Particle> _particles = [];
  final ui.Paint _paint = ui.Paint()..filterQuality = ui.FilterQuality.none;

  WeatherDef? _activeDef;
  ui.Image? _activeImage;
  Noise1D? _intensityNoise;
  double _currentOpacity = 0;
  double _targetOpacity = 0;
  double _frameTimer = 0;
  int _sharedFrame = 0;
  double _driftClock = 0;
  double _intensity = 1;
  // Last-seen scroll; per-frame delta shifts particles so flakes stay anchored
  // to world space (sliding left as the dino runs), not the screen.
  double _lastScrollOffset = 0;

  StreamSubscription<GameEvent>? _sub;

  @override
  Future<void> onLoad() async {
    // Streamer-added biomes load lazily via [ensureBiomeLoaded].
    final biomes = worldMap.segments.map((s) => s.biome).toSet();
    for (final biome in biomes) {
      await _loadAtlas(biome);
    }

    final initialBiome = worldMap.biomeAt(initialScrollOffset);
    final def = BiomeRegistry.get(initialBiome).weather;
    if (def != null) {
      _activate(def, _atlases[initialBiome]);
      _seedPrewarmed();
      // Cold-start fully visible, skipping the fade. Must set both current
      // and target, else update()'s fade tick walks opacity to the zero target.
      _currentOpacity = 1;
      _targetOpacity = 1;
    }
    _lastScrollOffset = camera.scrollOffset;

    _sub = _events.on<BiomeChanged>().listen(_onBiomeChanged);
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
      // Fade out; keep current particles.
      _targetOpacity = 0;
      return;
    }
    if (def == _activeDef) {
      _targetOpacity = 1;
      return;
    }
    // Def swap re-seeds hard (e.g. direct winter↔autumn morphs in-flight
    // particles); the 1.5s biome crossfade largely masks it.
    _activate(def, _atlases[event.current]);
    if (_currentOpacity == 0) _seedAboveScreen();
    _targetOpacity = 1;
  }

  void _activate(WeatherDef def, ui.Image? image) {
    _activeDef = def;
    _activeImage = image;
    _intensityNoise = def.intensityNoiseScale > 0
        ? Noise1D(worldMap.seed + def.intensitySeedOffset)
        : null;
    _resizePool(def.particleCount);
  }

  void _resizePool(int count) {
    if (_particles.length == count) return;
    if (_particles.length > count) {
      _particles.removeRange(count, _particles.length);
    } else {
      while (_particles.length < count) {
        // Stable per-particle threshold; intensity gates which flakes render
        // (low = light flurries, high = heavy squalls). Skewed toward zero
        // via pow(u, 1.8) because value noise rarely peaks near 1.0 —
        // uniform thresholds would leave many flakes that never render.
        final u = _rng.nextDouble();
        _particles
            .add(_Particle()..visibilityThreshold = pow(u, 1.8).toDouble());
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

  void _respawn(
    _Particle p,
    Vector2 size, {
    required bool fullHeight,
    double? enterFromX,
  }) {
    final def = _activeDef!;
    p.x = enterFromX ?? _rng.nextDouble() * size.x;
    if (fullHeight) {
      // Spread across the full lifecycle (staged above screen down to ground).
      // Seeding only the visible range would land every flake within seconds,
      // then gap until the next wave fell in from above.
      final groundTop = size.y * LexawayGame.groundLevel;
      final spawnTop = -size.y * 0.5;
      p.y = spawnTop + _rng.nextDouble() * (groundTop - spawnTop);
    } else {
      // Stagger above the top edge so they don't all enter at once.
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
    if (_currentOpacity != _targetOpacity) {
      final step = dt / _fadeDuration;
      if (_currentOpacity < _targetOpacity) {
        _currentOpacity = (_currentOpacity + step).clamp(0.0, 1.0);
      } else {
        _currentOpacity = (_currentOpacity - step).clamp(0.0, 1.0);
      }
    }

    if (_activeDef == null || (_currentOpacity == 0 && _targetOpacity == 0)) {
      return;
    }

    final def = _activeDef!;
    final scale = LexawayGame.pixelScale;
    final size = game.size;
    final spriteH = def.frameHeight * def.scale * scale;
    // Recycle when a flake's bottom crosses ground level so nothing renders
    // below the dino's feet line.
    final landY = size.y * LexawayGame.groundLevel - spriteH;

    _driftClock += dt;
    _frameTimer += dt;
    if (_frameTimer >= def.frameDuration) {
      final advance = (_frameTimer / def.frameDuration).floor();
      _sharedFrame = (_sharedFrame + advance) % def.frameCount;
      _frameTimer -= advance * def.frameDuration;
    }

    // Scroll delta so flakes drift with world space, not screen space.
    final scrollOffset = camera.scrollOffset;
    final scrollDelta = scrollOffset - _lastScrollOffset;
    _lastScrollOffset = scrollOffset;

    // Intensity from world position, stable per scroll offset (pause and it
    // sits still), so weather varies as you walk.
    if (_intensityNoise != null) {
      final tileX = scrollOffset / (16 * scale);
      final n = _intensityNoise!.sample(tileX, scale: def.intensityNoiseScale);
      _intensity = def.minIntensity + n * (def.maxIntensity - def.minIntensity);
    } else {
      _intensity = def.maxIntensity;
    }

    for (final p in _particles) {
      p.y += p.fallSpeed * scale * dt;
      // Sin-wave sway plus scroll delta so flakes live in world coords.
      p.x += sin(_driftClock * def.driftFrequency + p.phase) * p.drift * dt
          - scrollDelta;

      if (p.y > landY) {
        _respawn(p, size, fullHeight: false);
        continue;
      }

      // Re-enter from the opposite edge to keep feeding the screen. fullHeight
      // enters at a random visible Y; respawning above the top instead would
      // leave a sparse wedge on the leading edge during sustained motion.
      if (p.x < -spriteH) {
        _respawn(p, size, fullHeight: true, enterFromX: size.x + spriteH);
      } else if (p.x > size.x + spriteH) {
        _respawn(p, size, fullHeight: true, enterFromX: -spriteH);
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
      // Smooth fade across the threshold, no hard pop-in.
      final visibility = ((_intensity - p.visibilityThreshold) * 4)
          .clamp(0.0, 1.0);
      if (visibility <= 0) continue;

      final frame = (p.frameOffset + _sharedFrame) % def.frameCount;
      final src = ui.Rect.fromLTWH(
        frame * def.frameWidth,
        0,
        def.frameWidth,
        def.frameHeight,
      );
      // Snap to pixel grid for crisp art at integer scale.
      final px = (p.x / scale).round() * scale;
      final py = (p.y / scale).round() * scale;
      final dst = ui.Rect.fromLTWH(px, py, spriteW, spriteH);
      final alpha =
          (p.opacity * _currentOpacity * visibility * 255).round();
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
  double visibilityThreshold = 0;
}
