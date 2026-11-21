import 'package:flutter/material.dart';

import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';

/// Centered empty / error placeholder: icon, title, optional message and
/// action. Adapts its padding when the available height is small.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.hasBoundedHeight && constraints.maxHeight < 160;
          final padding = compact ? AppSpacing.lg : 32.0;
          final minHeight = constraints.hasBoundedHeight
              ? (constraints.maxHeight - (padding * 2))
                  .clamp(0.0, double.infinity)
                  .toDouble()
              : 0.0;
          return SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(icon, size: 48, color: AppColors.textMuted),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AppText.sectionTitle
                          .copyWith(fontSize: 16, color: AppColors.text),
                    ),
                    if (message != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.s6),
                      Text(
                        message!,
                        textAlign: TextAlign.center,
                        style: AppText.bodyMedium
                            .copyWith(color: AppColors.textMuted, height: 1.4),
                      ),
                    ],
                    if (action != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.lg),
                      action!
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      );
}
