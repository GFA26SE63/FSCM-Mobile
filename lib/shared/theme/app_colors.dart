import 'package:flutter/material.dart';

import 'package:fscm_mobile/core/utils/status_tone.dart';

/// Foreground / background pair of a status chip.
class ToneColors {
  const ToneColors(this.foreground, this.background);
  final Color foreground;
  final Color background;
}

/// Palette taken from the approved prototype (teal #14655B).
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF14655B);
  static const Color primaryDark = Color(0xFF0F5E55);
  static const Color primarySoft = Color(0xFFE1F1EC);
  static const Color background = Color(0xFFF3F4F1);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF1B1F1D);
  static const Color textMuted = Color(0xFF5B625E);
  static const Color border = Color(0xFFC9D0CB);
  static const Color divider = Color(0xFFE2E5E0);
  static const Color danger = Color(0xFFB42318);
  static const Color warning = Color(0xFF8A3B09);
  static const Color success = Color(0xFF15703A);

  static ToneColors tone(StatusTone tone) {
    switch (tone) {
      case StatusTone.neutral:
        return const ToneColors(Color(0xFF374151), Color(0xFFECEEF1));
      case StatusTone.info:
        return const ToneColors(Color(0xFF1D4ED8), Color(0xFFE8EEFD));
      case StatusTone.primary:
        return const ToneColors(Color(0xFF0F5E55), Color(0xFFE1F1EC));
      case StatusTone.success:
        return const ToneColors(Color(0xFF15703A), Color(0xFFE5F4EA));
      case StatusTone.purple:
        return const ToneColors(Color(0xFF6D28D9), Color(0xFFF1EAFE));
      case StatusTone.warning:
        return const ToneColors(Color(0xFF8A3B09), Color(0xFFFEF3E2));
      case StatusTone.danger:
        return const ToneColors(Color(0xFFB42318), Color(0xFFFDECEA));
    }
  }
}
