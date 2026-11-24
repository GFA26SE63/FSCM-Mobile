import 'package:flutter/material.dart';

import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';

/// Pill (`.chip`) showing a business status. The label and tone are chosen by
/// the caller; this widget only renders them.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.tone});

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.tone(tone);
    return Container(
      // 12px caption (1.3 line height) + 2×5 padding ≈ AppSizes.chip (26).
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: 5),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: AppRadius.pillAll,
      ),
      child: Text(
        label,
        style: AppText.caption.copyWith(color: c.foreground),
      ),
    );
  }
}
