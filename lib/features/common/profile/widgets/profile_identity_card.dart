import 'package:flutter/material.dart';

import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';

class ProfileIdentityCard extends StatelessWidget {
  const ProfileIdentityCard({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final email = user.email.trim();
    final phone = user.phone.trim();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primarySoft,
                child: Text(user.initials,
                    style:
                        AppText.pageTitle.copyWith(color: AppColors.primary)),
              ),
              const SizedBox(width: AppSpacing.card),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(user.fullName,
                        style: AppText.pageTitle
                            .copyWith(fontSize: 17, color: AppColors.text)),
                    const SizedBox(height: AppSpacing.xs),
                    StatusChip(
                        label: user.role.label, tone: StatusTone.primary),
                  ],
                ),
              ),
            ],
          ),
          if (email.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text('Email: $email', style: AppText.bodyMedium),
          ],
          if (phone.isNotEmpty &&
              phone.toLowerCase() != email.toLowerCase()) ...<Widget>[
            const SizedBox(height: AppSpacing.s6),
            Text('SĐT: $phone', style: AppText.bodyMedium),
          ],
          const Divider(height: 24),
          ..._scopeDetails(),
        ],
      ),
    );
  }

  List<Widget> _scopeDetails() {
    switch (user.role) {
      case UserRole.retailer:
        return <Widget>[
          _ScopeSection(
            title: 'Điểm bán',
            labels: user.retailerLabels
                .where((label) => user.retailerIds.contains(label.id))
                .toList(),
            legacyName: user.retailerName,
            legacyCode: user.retailerCode,
            useLegacyCode: true,
          ),
          if (user.retailerAddress?.trim().isNotEmpty == true) ...<Widget>[
            const SizedBox(height: AppSpacing.s6),
            Text('Địa chỉ: ${user.retailerAddress!.trim()}',
                style: AppText.bodyMedium),
          ],
        ];
      case UserRole.sales:
        return <Widget>[
          _ScopeSection(
            title: 'Nhóm bán hàng',
            labels: user.salesGroupLabels,
            legacyCode: user.salesGroup,
          ),
          const SizedBox(height: 12),
          _ScopeSection(
            title: 'Vùng phụ trách',
            labels: user.regionLabels,
            legacyName: user.areaName,
            legacyCode: user.areaCode,
          ),
        ];
      case UserRole.warehouseKeeper:
        return <Widget>[
          _ScopeSection(
            title: 'Kho phụ trách',
            labels: user.warehouseLabels,
            legacyName: user.warehouseName,
            legacyCode: user.warehouseCode,
          ),
        ];
      default:
        return <Widget>[Text(user.scopeText)];
    }
  }
}

class _ScopeSection extends StatelessWidget {
  const _ScopeSection({
    required this.title,
    required this.labels,
    this.legacyName,
    this.legacyCode,
    this.useLegacyCode = false,
  });

  final String title;
  final List<ScopeLabel> labels;
  final String? legacyName;
  final String? legacyCode;
  final bool useLegacyCode;

  String _description(String? name, String? code) {
    final parts = <String>[
      if (name?.trim().isNotEmpty == true) name!.trim(),
      if (code?.trim().isNotEmpty == true) 'Mã ${code!.trim()}',
    ];
    return parts.isEmpty ? 'Chưa có thông tin.' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title,
            style: AppText.label.copyWith(
                fontWeight: FontWeight.w700, color: AppColors.textMuted)),
        const SizedBox(height: AppSpacing.xs),
        if (labels.isEmpty)
          Text(_description(legacyName, legacyCode), style: AppText.bodyMedium)
        else
          for (final label in labels)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                  _description(
                      label.name, useLegacyCode ? legacyCode : label.code),
                  style: AppText.bodyMedium),
            ),
      ],
    );
  }
}
