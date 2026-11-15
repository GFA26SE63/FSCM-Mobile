import 'package:flutter/material.dart';

import 'package:fscm_mobile/shared/theme/app_colors.dart';

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
          final padding = compact ? 16.0 : 32.0;
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
                    Icon(icon, size: 48, color: AppColors.border),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    if (message != null) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        message!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.textMuted, height: 1.4),
                      ),
                    ],
                    if (action != null) ...<Widget>[
                      const SizedBox(height: 16),
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
