import 'package:intl/intl.dart';

/// Formats a step count as distance (one step = one in-game metre). Below 1km:
/// whole metres ("742 m"); at/above 1km: one decimal ("1.2 km"), locale-aware
/// separators.
String formatWalkedDistance(int steps, {String? locale}) {
  if (steps < 1000) {
    return '${NumberFormat.decimalPattern(locale).format(steps)} m';
  }
  final km = steps / 1000;
  return '${NumberFormat('#,##0.0', locale).format(km)} km';
}
