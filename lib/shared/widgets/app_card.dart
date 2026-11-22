import 'package:flutter/material.dart';

import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';

/// White card with a 1px hairline border (prototype `.card`), no elevation.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.card),
    this.margin = const EdgeInsets.only(bottom: AppSpacing.s10),
    this.color,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Material(
        color: color ?? AppColors.surface,
        borderRadius: AppRadius.cardAll,
        child: InkWell(
          borderRadius: AppRadius.cardAll,
          onTap: onTap,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: AppRadius.cardAll,
              border: Border.all(color: AppColors.divider),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
