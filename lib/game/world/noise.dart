/// Seed-deterministic 1D value noise with smooth interpolation.
///
/// Each [Noise1D] instance produces a repeatable stream of smooth, continuous
/// values in [0, 1] for any real-valued coordinate. Different seeds (or seed
/// offsets) yield uncorrelated patterns — perfect for stacking independent
/// spawn layers, Minecraft-style.
class Noise1D {
  final int _seed;

  const Noise1D(this._seed);

  /// Returns a smooth noise value in [0, 1] at position [x].
  ///
  /// [scale] controls the frequency — smaller values produce broader hills,
  /// larger values produce tighter variation.
  double sample(double x, {double scale = 1.0}) {
    final sx = x * scale;
    final ix = sx.floor();
    final t = sx - ix;
    // Smoothstep for C1 continuity (no harsh kinks).
    final s = t * t * (3.0 - 2.0 * t);
    return _lerp(_hash(ix), _hash(ix + 1), s);
  }

  /// Hash an integer lattice point to a value in [0, 1].
  ///
  /// Uses a simple but well-distributed integer hash (Bob Jenkins' OAT).
  double _hash(int i) {
    // 32-bit masking after each step keeps this correct on web (JS numbers are
    // 53-bit doubles) while being a no-op on native 64-bit ints.
    var h = (_seed ^ i) & 0xFFFFFFFF;
    h = ((h + 0x7ed55d16) + (h << 12)) & 0xFFFFFFFF;
    h = ((h ^ 0xc761c23c) ^ (h >> 19)) & 0xFFFFFFFF;
    h = ((h + 0x165667b1) + (h << 5)) & 0xFFFFFFFF;
    h = ((h + 0xd3a2646c) ^ (h << 9)) & 0xFFFFFFFF;
    h = ((h + 0xfd7046c5) + (h << 3)) & 0xFFFFFFFF;
    h = ((h ^ 0xb55a4f09) ^ (h >> 16)) & 0xFFFFFFFF;
    // Map to [0, 1].
    return (h & 0x7FFFFFFF) / 0x7FFFFFFF;
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}
