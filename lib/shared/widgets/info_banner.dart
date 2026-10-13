import 'package:flutter/material.dart';

import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';

/// Inline notice (offline mode, promotion changed, rejection reason...).
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: c.foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (title != null)
                  Text(
                    title!,
                    style: TextStyle(
                        color: c.foreground, fontWeight: FontWeight.w700),
                  ),
                Text(text, style: TextStyle(color: c.foreground, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
