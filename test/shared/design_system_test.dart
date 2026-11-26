import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/app/theme.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Be Vietnam Pro is bundled in all four weights (no network needed)',
      () async {
    for (final w in <String>['Regular', 'Medium', 'SemiBold', 'Bold']) {
      final data = await rootBundle.load('assets/fonts/BeVietnamPro-$w.ttf');
      expect(data.lengthInBytes, greaterThan(50000), reason: w);
    }
    final licence = await rootBundle.loadString('assets/fonts/OFL.txt');
    expect(licence, contains('SIL Open Font License'));
  });

  test('theme is built from the design tokens', () {
    final t = buildAppTheme();
    expect(t.textTheme.bodyMedium!.fontFamily, AppText.fontFamily);
    expect(t.scaffoldBackgroundColor, AppColors.background);
    expect(t.colorScheme.primary, AppColors.primary);
    expect(t.appBarTheme.toolbarHeight, AppSizes.header);
    // Titles of screens without a back button must not touch the left edge.
    expect(t.appBarTheme.titleSpacing, AppSpacing.lg);
    expect(t.navigationBarTheme.height, AppSizes.navBar);
    expect(t.cardTheme.shape, isA<RoundedRectangleBorder>());
    final filled = t.filledButtonTheme.style!;
    expect(
        filled.minimumSize!.resolve(<WidgetState>{})!.height, AppSizes.control);
    expect(AppRadius.card, 14);
    expect(AppRadius.control, 12);
  });

  test('every status tone keeps a distinct foreground/background pair', () {
    final pairs = <String>{};
    for (final tone in StatusTone.values) {
      final c = AppColors.tone(tone);
      expect(c.foreground, isNot(c.background));
      pairs.add('${c.foreground}/${c.background}');
    }
    expect(pairs.length, StatusTone.values.length);
  });
}
