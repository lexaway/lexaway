/// Declarative config for a falling-sky effect (snow, petals, fireflies,
/// motes). Held by [BiomeDefinition.weather] so a biome opts in with one
/// registry line.
///
/// Fields stay primitive so the biome literal stays `const`-constructible —
/// Flame's mutable [Vector2] can't appear in const context (same rationale
/// as [CreatureSpriteDef]).
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
  /// No coupling to run speed — that's [WindLines]'s job and would clash.
  final double driftAmplitude;
  final double driftFrequency;

  /// Per-particle opacity range. Gives depth without per-biome paint code.
  final double minOpacity;
  final double maxOpacity;

  /// Render scale, multiplied with [LexawayGame.pixelScale]. Use 1.0 for
  /// pixel-art chunky 1:1, or fractional for "distant" specks.
  final double scale;

  /// Density-variation noise frequency in tiles (16 px each) — small = broad
  /// fronts, large = patchy gusts. `0` disables variation and locks intensity
  /// at [maxIntensity]. Modulates flake count and a bit of fall speed.
  final double intensityNoiseScale;

  /// Intensity range when noise is active; the sample maps into
  /// `[minIntensity, maxIntensity]` and gates per-particle visibility. Not
  /// linear — most flakes have low thresholds, so `0.15` still drifts sparse
  /// while `0` reads as clear sky and `1.0` reveals the full pool.
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

  /// Falling autumn leaves — recolored copy of the snow strip (7 x 8x8
  /// frames); the twinkle cycle reads as leaf flutter. Slower fall, wider
  /// sway than snow.
  static const autumnLeaves = WeatherDef(
    spritePath: 'fx/leaves.png',
    frameCount: 7,
    frameWidth: 8,
    frameHeight: 8,
    frameDuration: 0.22,
    particleCount: 60,
    minFallSpeed: 18,
    maxFallSpeed: 34,
    driftAmplitude: 26,
    driftFrequency: 0.8,
    minOpacity: 0.7,
    maxOpacity: 1.0,
    scale: 0.5,
    intensityNoiseScale: 0.03,
    // A forest always sheds a few leaves — never fully clear.
    minIntensity: 0.15,
    maxIntensity: 0.9,
    // != snow's 7 so gust fronts desync across biomes.
    intensitySeedOffset: 11,
  );
}
