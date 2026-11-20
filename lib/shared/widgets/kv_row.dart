import 'package:flutter/material.dart';

import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';

/// Label / value row (prototype `.kv`): muted label, right-aligned value.
class KvRow extends StatelessWidget {
  const KvRow(this.label, this.value,
      {super.key, this.bold = false, this.valueColor});

  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            flex: 4,
            child: Text(label,
                style: AppText.bodyMedium.copyWith(color: AppColors.textMuted)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppText.bodyMedium.copyWith(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: valueColor ?? AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
