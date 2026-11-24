/// Typography of the FSCM Mobile design system (single source).
///
/// Font: Be Vietnam Pro (SIL OFL 1.1), bundled in `assets/fonts/`, weights
/// 400 / 500 / 600 / 700. Sizes and weights follow the prototype v1.5 CSS.
/// Colours are intentionally *not* baked in here, except where a role has a
/// fixed colour (label/caption); widgets pick colours from `AppColors`.
library;

import 'package:flutter/material.dart';

import 'package:fscm_mobile/shared/theme/app_colors.dart';

class AppText {
  AppText._();

  static const String fontFamily = 'BeVietnamPro';

  /// Page title (`h2` in forms / login heading): 20 / 700.
  static const TextStyle display = TextStyle(
      fontFamily: fontFamily,
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 1.25);

  /// Header title (`.hdr h1`): 18 / 700.
  static const TextStyle pageTitle = TextStyle(
      fontFamily: fontFamily,
      fontSize: 18,
      fontWeight: FontWeight.w700,
      height: 1.2);

  /// Section heading: 15 / 700.
  static const TextStyle sectionTitle = TextStyle(
      fontFamily: fontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w700,
      height: 1.3);

  /// Card / row title: 15 / 600.
  static const TextStyle cardTitle = TextStyle(
      fontFamily: fontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.3);

  /// Body large (inputs, rows): 15 / 400.
  static const TextStyle bodyLarge = TextStyle(
      fontFamily: fontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      height: 1.4);

  /// Body medium (`.kv`, default text): 14 / 400.
  static const TextStyle bodyMedium = TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.4);

  /// Body small (secondary lines): 12.5 / 400.
  static const TextStyle bodySmall = TextStyle(
      fontFamily: fontFamily,
      fontSize: 12.5,
      fontWeight: FontWeight.w400,
      height: 1.4);

  /// Secondary body line: 14 / 400, muted colour.
  static const TextStyle muted = TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: AppColors.textMuted);

  /// Secondary small line: 12.5 / 400, muted colour.
  static const TextStyle mutedSmall = TextStyle(
      fontFamily: fontFamily,
      fontSize: 12.5,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: AppColors.textMuted);

  /// Emphasised value (amounts, codes): 15 / 700.
  static const TextStyle strong = TextStyle(
      fontFamily: fontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w700,
      height: 1.3);

  /// Field / form label (`.field`): 13 / 600.
  static const TextStyle label = TextStyle(
      fontFamily: fontFamily,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 1.3,
      color: AppColors.textLabel);

  /// Caption, chips, nav labels: 12 / 600.
  static const TextStyle caption = TextStyle(
      fontFamily: fontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.3);

  /// Bottom navigation label (`.tab`): 11 / 600.
  static const TextStyle navLabel = TextStyle(
      fontFamily: fontFamily,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      height: 1.2);

  /// Buttons (`.btn`): 15 / 600.
  static const TextStyle button = TextStyle(
      fontFamily: fontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.2);

  /// Text buttons (`.btn-text`): 14 / 600.
  static const TextStyle buttonSmall = TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.2);

  /// Material [TextTheme] mapped from the scale above.
  static const TextTheme textTheme = TextTheme(
    displayLarge: display,
    displayMedium: display,
    displaySmall: display,
    headlineLarge: display,
    headlineMedium: display,
    headlineSmall: pageTitle,
    titleLarge: pageTitle,
    titleMedium: cardTitle,
    titleSmall: buttonSmall,
    bodyLarge: bodyLarge,
    bodyMedium: bodyMedium,
    bodySmall: bodySmall,
    labelLarge: button,
    labelMedium: caption,
    labelSmall: navLabel,
  );
}
