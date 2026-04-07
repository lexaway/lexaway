import 'package:flutter/material.dart';

/// Centralised color palette for the Lexaway UI.
abstract final class AppColors {
  // Backgrounds (shade900 = darkest → shade600 = lightest)
  static final scaffold = Colors.brown.shade900;
  static final surface = Colors.brown.shade800;
  static final surfaceBright = Colors.brown.shade700;
  static final surfaceBorder = Colors.brown.shade600;

  // Text, icons, and indicators (on dark backgrounds)
  static const textPrimary = Colors.white;
  static const textSecondary = Colors.white70;
  static const textTertiary = Colors.white54;
  static const textFaint = Colors.white38;

  // Accent
  static final accent = Colors.amber.shade600;
  static final accentLight = Colors.amber.shade400;
  static final accentDark = Colors.amber.shade800;

  // Semantic
  static const success = Colors.green;
  static final successDark = Colors.green.shade700;
  static final successLight = Colors.green.shade400;
  static final error = Colors.red.shade400;

  // Controls (sliders, switches)
  static final controlInactive = Colors.blueGrey.shade700;
  static final controlInactiveThumb = Colors.blueGrey.shade300;
}
