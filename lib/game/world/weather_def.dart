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
  })  : assert(frameCount > 0),
        assert(minFallSpeed > 0 && maxFallSpeed >= minFallSpeed),
        assert(minOpacity >= 0 && maxOpacity <= 1.0 && maxOpacity >= minOpacity);

  /// Snow flakes — Ninja Adventure FX/Particle/Snow.png, 56x8 = 7 frames.
  static const snow = WeatherDef(
    spritePath: 'fx/snow.png',
    frameCount: 7,
    frameWidth: 8,
    frameHeight: 8,
    frameDuration: 0.18,
    particleCount: 80,
    minFallSpeed: 25,
    maxFallSpeed: 55,
    driftAmplitude: 14,
    driftFrequency: 0.6,
    minOpacity: 0.55,
    maxOpacity: 1.0,
    scale: 1.0,
  );
}
