/// Layout tokens of the FSCM Mobile design system (single source).
///
/// Values come from `docs/design/FSCM_Prototype_Prod_v1.5.html` (shared CSS of
/// the `mobile/sales/retailer/warehouse` apps). Colours live in
/// `app_colors.dart`, text styles in `app_text.dart`.
library;

import 'package:flutter/widgets.dart';

/// Spacing scale (multiples of 4, plus the prototype's half step 2/6/10/14).
class AppSpacing {
  AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;

  /// Prototype card inner padding (14) and half steps used by rows.
  static const double card = 14;
  static const double s6 = 6;
  static const double s10 = 10;

  /// Horizontal gutter of a screen.
  static const double screen = 16;
}

/// Corner radii.
class AppRadius {
  AppRadius._();

  /// `.card`, list rows, banners-as-cards.
  static const double card = 14;

  /// `.btn`, `.input`, `.iconbtn`, banners.
  static const double control = 12;

  /// `.step` / `.qty` quantity controls.
  static const double small = 10;

  /// Dialogs and bottom sheets.
  static const double sheet = 16;

  /// `.chip` pill.
  static const double pill = 999;

  static const BorderRadius cardAll = BorderRadius.all(Radius.circular(card));
  static const BorderRadius controlAll =
      BorderRadius.all(Radius.circular(control));
  static const BorderRadius smallAll = BorderRadius.all(Radius.circular(small));
  static const BorderRadius sheetAll = BorderRadius.all(Radius.circular(sheet));
  static const BorderRadius sheetTop =
      BorderRadius.vertical(top: Radius.circular(sheet));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

/// Fixed component dimensions.
class AppSizes {
  AppSizes._();

  /// `.btn` / `.input` height.
  static const double control = 48;

  /// `.iconbtn`.
  static const double iconButton = 44;

  /// Minimum touch target of text buttons.
  static const double touch = 44;

  /// `.hdr` min-height.
  static const double header = 62;

  /// `.tabbar` height.
  static const double navBar = 68;

  /// `.chip` height.
  static const double chip = 26;

  /// Horizontal filter chip height (`height:36px` in the prototype).
  static const double filterChip = 36;

  /// Tab bar icon size.
  static const double navIcon = 22;
}
