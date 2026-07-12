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

  // Text on light tile/parchment backgrounds
  static const tileText = Color(0xFF3B2816);
  static const tileTextSecondary = Color(0xFF6B4C30);
  static const tileTextFaint = Color(0xFF9C7B5A);

  static final accent = Colors.amber.shade600;
  static final accentLight = Colors.amber.shade400;
  static final accentDark = Colors.amber.shade800;

  static const success = Colors.green;
  static final successDark = Colors.green.shade700;
  static final successLight = Colors.green.shade400;
  static final error = Colors.red.shade400;

  // Controls (sliders, switches)
  static final controlInactive = Colors.blueGrey.shade700;
  static final controlInactiveThumb = Colors.blueGrey.shade300;
}

/// Carnival palette shared by the claw-machine prompt and result dialog.
abstract final class ClawColors {
  static const frame = Color(0xFFC2185B); // border, titles, accents
  static const panel = Color(0xFFFFE0AC); // dialog background
  static const text = Color(0xFF3E2723); // body text on the panel
  static const textOwned = Color(0xFF8D6E63); // "already owned" hint
  static const warning = Color(0xFFB00020); // "not enough coins" notice
  static const action = Color(0xFFFF4081); // primary (play / try again)
  static const actionDisabled = Color(0xFFD8B4A0);
  static const decline = Color(0xFFE0E0E0); // "walk past" button
}
