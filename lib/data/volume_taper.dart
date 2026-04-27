/// Maps a linear slider position [0..1] to an audio amplitude multiplier.
///
/// Hearing is logarithmic — feeding the raw slider value straight into
/// `setVolume()` makes the top half feel front-loaded and the bottom half
/// feel useless. Squaring the position is the standard DAW fader taper:
/// slider 0.5 → amplitude 0.25 (-12 dB), much closer to "halfway feels half
/// as loud". A cube law would feel even more proportional but compounds
/// too aggressively when multiple sliders multiply (master × channel).
double taperedVolume(double slider) {
  final v = slider.clamp(0.0, 1.0);
  return v * v;
}
