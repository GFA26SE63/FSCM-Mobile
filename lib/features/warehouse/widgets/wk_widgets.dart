import 'package:flutter/material.dart';

import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';

/// Presentation helpers shared by the WarehouseKeeper screens. They only render
/// values the screens already compute; no business rule lives here.

/// Chip colour for a warehouse-document status code (label text comes from
/// `warehouseStatus`).
StatusTone wkStatusTone(Object? status) => switch (status) {
      'Open' => StatusTone.warning,
      'Prepared' => StatusTone.info,
      'Posted' || 'Executed' || 'Fulfilled' => StatusTone.success,
      _ => StatusTone.neutral,
    };

/// Soft icon tile used on cards (prototype 40px rounded tile).
class WkIconTile extends StatelessWidget {
  const WkIconTile(this.icon,
      {super.key, this.color = AppColors.primary, this.size = 40});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: AppRadius.controlAll,
        ),
        child: Icon(icon, color: color, size: size * 0.5),
      );
}

/// Entry card of an operation: icon tile, title, one-line summary, chevron.
class WkOperationCard extends StatelessWidget {
  const WkOperationCard({
    super.key,
    required this.icon,
    required this.title,
    required this.summary,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
        onTap: onTap,
        child: Row(children: <Widget>[
          WkIconTile(icon),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: AppText.cardTitle),
                Text(summary, style: AppText.mutedSmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ]),
      );
}

/// Document row: code + status chip, type/route line, optional quantity.
class WkDocumentCard extends StatelessWidget {
  const WkDocumentCard({
    super.key,
    required this.code,
    required this.subtitle,
    required this.onTap,
    this.statusLabel,
    this.tone = StatusTone.neutral,
    this.trailingNote,
    this.color,
  });

  final String code;
  final String subtitle;
  final VoidCallback onTap;
  final String? statusLabel;
  final StatusTone tone;
  final String? trailingNote;
  final Color? color;

  @override
  Widget build(BuildContext context) => AppCard(
        onTap: onTap,
        color: color,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: <Widget>[
                    Text(code, style: AppText.strong),
                    if (statusLabel != null)
                      StatusChip(label: statusLabel!, tone: tone),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(subtitle, style: AppText.bodySmall),
                if (trailingNote != null)
                  Text(trailingNote!, style: AppText.mutedSmall),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: AppSpacing.xs),
            child: Icon(Icons.chevron_right, color: AppColors.textMuted),
          ),
        ]),
      );
}

/// White stat card: small label above a large number.
class WkStatCard extends StatelessWidget {
  const WkStatCard(
      {super.key,
      required this.label,
      required this.value,
      this.color = AppColors.text});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => AppCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: AppText.mutedSmall.copyWith(fontSize: 12)),
            const SizedBox(height: AppSpacing.xs),
            Text(value,
                style: AppText.display.copyWith(fontSize: 24, color: color)),
          ],
        ),
      );
}
