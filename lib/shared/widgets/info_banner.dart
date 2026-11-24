import 'package:flutter/material.dart';

import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';

/// Tone banner (info / success / warning / danger ...), text and icon use the
/// foreground of the tone on its soft background.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.text,
    this.tone = StatusTone.info,
    this.icon = Icons.info_outline,
    this.title,
  });

  final String text;
  final String? title;
  final StatusTone tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.tone(tone);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.s10),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: AppRadius.controlAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: c.foreground),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (title != null)
                  Text(
                    title!,
                    style: AppText.cardTitle
                        .copyWith(color: c.foreground, fontSize: 14),
                  ),
                Text(
                  text,
                  style: AppText.bodyMedium
                      .copyWith(color: c.foreground, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
