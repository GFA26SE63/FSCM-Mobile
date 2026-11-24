import 'package:flutter/material.dart';

import 'package:fscm_mobile/core/utils/status_tone.dart';

/// Foreground / background pair of a status chip.
class ToneColors {
  const ToneColors(this.foreground, this.background);
  final Color foreground;
  final Color background;
}

/// Colour tokens of the FSCM Mobile design system (single source).
///
/// Canonical values come from `docs/design/FSCM_Prototype_Prod_v1.5.html`.
/// Where the prototype is inconsistent between its mobile CSS sections the
/// chosen value and the discarded variants are:
/// * warning text `#8A3B09` (drops `#7A3408`, `#8A4B0C`, `#7A5200`)
/// * success text `#15703A` (drops `#14532D`)
/// * danger text `#B42318` (drops the chip-only `#8F1D14`)
/// * purple text `#4C1D95` (Flutter used `#6D28D9`)
/// * screen background `#F3F4F1` (frame colour of every mobile app)
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------- brand
  static const Color primary = Color(0xFF14655B);
  static const Color primaryDark = Color(0xFF0F5E55);
  static const Color primarySoft = Color(0xFFE1F1EC);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // ------------------------------------------------------------- surfaces
  static const Color background = Color(0xFFF3F4F1);
  static const Color surface = Color(0xFFFFFFFF);

  // ----------------------------------------------------------------- text
  static const Color text = Color(0xFF1B1F1D);
  static const Color textMuted = Color(0xFF5B625E);

  /// Form label (`.field`).
  static const Color textLabel = Color(0xFF3D4441);

  // ---------------------------------------------------- borders / disabled
  /// Input and outlined-control border.
  static const Color border = Color(0xFFC9D0CB);

  /// Card border and hairline divider (`.card` / `.hdr` / `.tabbar`).
  static const Color divider = Color(0xFFE2E5E0);

  /// Disabled primary button fill.
  static const Color disabled = Color(0xFFA7B8B3);

  // ------------------------------------------------------ semantic status
  static const Color danger = Color(0xFFB42318);
  static const Color dangerSoft = Color(0xFFFDECEA);

  /// Border of a danger outlined button (`.btn-danger`).
  static const Color dangerBorder = Color(0xFFE7B4AE);
  static const Color warning = Color(0xFF8A3B09);
  static const Color warningSoft = Color(0xFFFEF3E2);
  static const Color success = Color(0xFF15703A);
  static const Color successSoft = Color(0xFFE5F4EA);
  static const Color info = Color(0xFF1D4ED8);
  static const Color infoSoft = Color(0xFFE8EEFD);

  // -------------------------------------------------------------- overlay
  /// Modal barrier (`rgba(20,24,22,.5)` in the prototype).
  static const Color scrim = Color(0x80141816);

  /// Status chip / banner pair for a business tone.
  static ToneColors tone(StatusTone tone) {
    switch (tone) {
      case StatusTone.neutral:
        return const ToneColors(Color(0xFF374151), Color(0xFFECEEF1));
      case StatusTone.info:
        return const ToneColors(info, infoSoft);
      case StatusTone.primary:
        return const ToneColors(primaryDark, primarySoft);
      case StatusTone.success:
        return const ToneColors(success, successSoft);
      case StatusTone.purple:
        return const ToneColors(Color(0xFF4C1D95), Color(0xFFF1EAFE));
      case StatusTone.warning:
        return const ToneColors(warning, warningSoft);
      case StatusTone.danger:
        return const ToneColors(danger, dangerSoft);
    }
  }
}
