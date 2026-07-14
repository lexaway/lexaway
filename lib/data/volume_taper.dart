/// Maps a linear slider [0..1] to an amplitude multiplier.
///
/// Hearing is logarithmic, so raw slider values feel front-loaded. Squaring is
/// the standard DAW fader taper (0.5 → 0.25 ≈ -12 dB). Cube would compound too
/// hard when sliders multiply (master × channel).
double taperedVolume(double slider) {
  final v = slider.clamp(0.0, 1.0);
  return v * v;
}
