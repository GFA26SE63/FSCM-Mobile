import 'package:flutter/material.dart';

import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';

/// Material 3 theme built only from the design-system tokens
/// (`app_colors.dart`, `app_text.dart`, `app_tokens.dart`), following
/// `FSCM_Prototype_Prod_v1.5.html`.
ThemeData buildAppTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.primarySoft,
    onPrimaryContainer: AppColors.primaryDark,
    secondary: AppColors.primaryDark,
    onSecondary: AppColors.onPrimary,
    secondaryContainer: AppColors.primarySoft,
    onSecondaryContainer: AppColors.primaryDark,
    tertiary: AppColors.info,
    onTertiary: AppColors.onPrimary,
    tertiaryContainer: AppColors.infoSoft,
    onTertiaryContainer: AppColors.info,
    error: AppColors.danger,
    onError: AppColors.onPrimary,
    errorContainer: AppColors.dangerSoft,
    onErrorContainer: AppColors.danger,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    onSurfaceVariant: AppColors.textMuted,
    outline: AppColors.border,
    outlineVariant: AppColors.divider,
    surfaceTint: Colors.transparent,
    surfaceContainerLowest: AppColors.surface,
    surfaceContainerLow: AppColors.surface,
    surfaceContainer: AppColors.background,
    surfaceContainerHigh: AppColors.background,
    surfaceContainerHighest: AppColors.background,
    scrim: AppColors.scrim,
  );

  const controlShape =
      RoundedRectangleBorder(borderRadius: AppRadius.controlAll);
  const buttonMinHeight = AppSizes.control;

  OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: AppRadius.controlAll,
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    useMaterial3: true,
    fontFamily: AppText.fontFamily,
    colorScheme: scheme,
    textTheme: AppText.textTheme
        .apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.surface,
    splashFactory: InkRipple.splashFactory,
    iconTheme: const IconThemeData(color: AppColors.text, size: 24),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: AppSizes.header,
      titleSpacing: AppSpacing.lg,
      shape: const Border(bottom: BorderSide(color: AppColors.divider)),
      titleTextStyle: AppText.pageTitle.copyWith(color: AppColors.text),
      iconTheme: const IconThemeData(color: AppColors.text, size: 24),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardAll,
        side: BorderSide(color: AppColors.divider),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.card, vertical: AppSpacing.card),
      labelStyle: AppText.bodyLarge.copyWith(color: AppColors.textMuted),
      floatingLabelStyle: AppText.label,
      hintStyle: AppText.bodyLarge.copyWith(color: AppColors.textMuted),
      helperStyle: AppText.bodySmall.copyWith(color: AppColors.textMuted),
      errorStyle: AppText.bodySmall.copyWith(color: AppColors.danger),
      border: inputBorder(AppColors.border),
      enabledBorder: inputBorder(AppColors.border),
      focusedBorder: inputBorder(AppColors.primary, 1.6),
      errorBorder: inputBorder(AppColors.danger),
      focusedErrorBorder: inputBorder(AppColors.danger, 1.6),
      disabledBorder: inputBorder(AppColors.divider),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        disabledBackgroundColor: AppColors.disabled,
        disabledForegroundColor: AppColors.onPrimary,
        minimumSize: const Size.fromHeight(buttonMinHeight),
        shape: controlShape,
        textStyle: AppText.button,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        disabledBackgroundColor: AppColors.disabled,
        disabledForegroundColor: AppColors.onPrimary,
        elevation: 0,
        minimumSize: const Size(0, buttonMinHeight),
        shape: controlShape,
        textStyle: AppText.button,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primary,
        disabledForegroundColor: AppColors.textMuted,
        minimumSize: const Size(0, buttonMinHeight),
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        shape: controlShape,
        textStyle: AppText.button,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        disabledForegroundColor: AppColors.textMuted,
        minimumSize: const Size(0, AppSizes.touch),
        shape: controlShape,
        textStyle: AppText.buttonSmall,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.text,
        minimumSize: const Size.square(AppSizes.iconButton),
        shape: controlShape,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        textStyle: const WidgetStatePropertyAll<TextStyle>(AppText.label),
        shape: const WidgetStatePropertyAll<OutlinedBorder>(controlShape),
        side: const WidgetStatePropertyAll<BorderSide>(
            BorderSide(color: AppColors.border)),
        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.primaryDark
                : AppColors.text),
        backgroundColor: WidgetStateProperty.resolveWith<Color>((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.primarySoft
                : AppColors.surface),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.primary,
      disabledColor: AppColors.background,
      side: const BorderSide(color: AppColors.border),
      shape: const StadiumBorder(),
      labelStyle: AppText.label.copyWith(color: AppColors.text),
      secondaryLabelStyle: AppText.label.copyWith(color: AppColors.onPrimary),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetAll),
      titleTextStyle: AppText.pageTitle.copyWith(color: AppColors.text),
      contentTextStyle: AppText.bodyMedium.copyWith(color: AppColors.text),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: AppColors.surface,
      modalBarrierColor: AppColors.scrim,
      elevation: 0,
      modalElevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
      clipBehavior: Clip.antiAlias,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.text,
      contentTextStyle: AppText.bodyMedium.copyWith(color: AppColors.onPrimary),
      actionTextColor: AppColors.onPrimary,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.controlAll),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      height: AppSizes.navBar,
      indicatorColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
        final selected = states.contains(WidgetState.selected);
        return AppText.navLabel.copyWith(
          color: selected ? AppColors.primary : AppColors.textMuted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: AppSizes.navIcon,
          color: selected ? AppColors.primary : AppColors.textMuted,
        );
      }),
    ),
    badgeTheme: BadgeThemeData(
      backgroundColor: AppColors.danger,
      textColor: AppColors.onPrimary,
      textStyle:
          AppText.navLabel.copyWith(fontSize: 10, fontWeight: FontWeight.w700),
      smallSize: 8,
      largeSize: 18,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.textMuted,
      labelStyle: AppText.buttonSmall,
      unselectedLabelStyle: AppText.buttonSmall,
      indicatorColor: AppColors.primary,
      dividerColor: AppColors.divider,
      indicatorSize: TabBarIndicatorSize.tab,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      circularTrackColor: AppColors.primarySoft,
    ),
    dividerTheme: const DividerThemeData(
        color: AppColors.divider, thickness: 1, space: 1),
    listTileTheme: ListTileThemeData(
      iconColor: AppColors.textMuted,
      textColor: AppColors.text,
      titleTextStyle: AppText.cardTitle.copyWith(color: AppColors.text),
      subtitleTextStyle: AppText.bodySmall.copyWith(color: AppColors.textMuted),
    ),
  );
}
