/// Declarative config for a "stuff falling from the sky" effect — snow,
/// sakura petals, fireflies, dust motes, anything that's a small drifting
/// sprite. Held by [BiomeDefinition.weather] so a biome opts in by adding
/// one line to its registry entry.
///
/// Field types are kept primitive (String/int/double) so the surrounding
/// biome literal stays `const`-constructible — Flame's [Vector2] is mutable
/// and can't appear in const context, matching the rationale on
/// [CreatureSpriteDef].
class WeatherDef {
  /// Sprite sheet path relative to `assets/images/`. Expected layout: a
  /// horizontal strip of [frameCount] frames, each [frameWidth] x [frameHeight].
  final String spritePath;
  final int frameCount;
  final double frameWidth;
  final double frameHeight;

  /// Seconds per frame, shared across all particles. Each particle starts
  /// on a random frame offset so the population reads as desynced twinkle
  /// instead of pulsing in unison.
  final double frameDuration;

  /// Pool size. Particles are recycled, never destroyed.
  final int particleCount;

  /// Logical px/sec falling speed range, picked uniformly per particle.
  /// Multiplied by [LexawayGame.pixelScale] at render time.
  final double minFallSpeed;
  final double maxFallSpeed;

  /// Horizontal sway: `x += sin(t * driftFrequency + phase) * driftAmplitude * dt`.
  /// Pure sin-wave, no coupling to player run speed (that would conflict
  /// visually with [WindLines], which already shows running motion).
  final double driftAmplitude;
  final double driftFrequency;

  /// Per-particle opacity range. Gives depth without per-biome paint code.
  final double minOpacity;
  final double maxOpacity;

  /// Render scale, multiplied with [LexawayGame.pixelScale]. Use 1.0 for
  /// pixel-art chunky 1:1, or fractional for "distant" specks.
  final double scale;

  /// Noise frequency in *tiles* (16 logical px each) for varying density
  /// across the biome — small values = broad weather "fronts", larger values
  /// = patchy gusts. `0` disables variation and locks intensity at
  /// [maxIntensity]. Heaviness modulates visible flake count and a small
  /// fraction of fall speed, so the biome reads as light flurries in some
  /// stretches and thicker squalls in others.
  final double intensityNoiseScale;

  /// Intensity range when noise is active. The active sample is mapped into
  /// `[minIntensity, maxIntensity]` and gates per-particle visibility. Low
  /// values aren't a linear "fewer flakes" — most flakes have low visibility
  /// thresholds, so e.g. `0.15` still shows a sparse drift, while `0` lets
  /// noise troughs read as completely clear sky. `1.0` reveals the full pool.
  final double minIntensity;
  final double maxIntensity;

  /// Seed offset for the intensity noise. Independent from world generation
  /// noise — different offsets make different effects vary asynchronously.
  final int intensitySeedOffset;

  const WeatherDef({
    required this.spritePath,
    required this.frameCount,
    required this.frameWidth,
    required this.frameHeight,
    required this.frameDuration,
    required this.particleCount,
    required this.minFallSpeed,
    required this.maxFallSpeed,
    required this.driftAmplitude,
    required this.driftFrequency,
    required this.minOpacity,
    required this.maxOpacity,
    required this.scale,
    this.intensityNoiseScale = 0,
    this.minIntensity = 1.0,
    this.maxIntensity = 1.0,
    this.intensitySeedOffset = 0,
  })  : assert(frameCount > 0),
        assert(minFallSpeed > 0 && maxFallSpeed >= minFallSpeed),
        assert(minOpacity >= 0 && maxOpacity <= 1.0 && maxOpacity >= minOpacity),
        assert(intensityNoiseScale >= 0),
        assert(minIntensity >= 0 && maxIntensity <= 1.0),
        assert(maxIntensity >= minIntensity);

  /// Snow flakes — Ninja Adventure FX/Particle/Snow.png, 56x8 = 7 frames.
  /// Capacity is sized for the heaviest squall; intensity noise dials it
  /// down to flurries elsewhere.
  static const snow = WeatherDef(
    spritePath: 'fx/snow.png',
    frameCount: 7,
    frameWidth: 8,
    frameHeight: 8,
    frameDuration: 0.18,
    particleCount: 90,
    minFallSpeed: 26,
    maxFallSpeed: 48,
    driftAmplitude: 14,
    driftFrequency: 0.6,
    minOpacity: 0.55,
    maxOpacity: 1.0,
    scale: 0.5,
    // ~0.025 tiles ≈ 40-tile period ≈ 32 seconds at walk speed — broad
    // squalls that read as "the weather just changed" rather than flicker.
    intensityNoiseScale: 0.025,
    minIntensity: 0,
    maxIntensity: 1.0,
    intensitySeedOffset: 7,
  );
}
