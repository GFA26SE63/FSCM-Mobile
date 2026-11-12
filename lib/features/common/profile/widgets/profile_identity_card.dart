import 'package:flutter/material.dart';

import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
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
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(user.fullName,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(user.role.label,
                        style: const TextStyle(color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          if (email.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text('Email: $email'),
          ],
          if (phone.isNotEmpty &&
              phone.toLowerCase() != email.toLowerCase()) ...<Widget>[
            const SizedBox(height: 6),
            Text('SĐT: $phone'),
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
            const SizedBox(height: 6),
            Text('Địa chỉ: ${user.retailerAddress!.trim()}'),
          ],
        ];
      case UserRole.sales:
        return <Widget>[
          _ScopeSection(
            title: 'Nhóm Sales',
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
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        if (labels.isEmpty)
          Text(_description(legacyName, legacyCode))
        else
          for (final label in labels)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(_description(
                  label.name, useLegacyCode ? legacyCode : label.code)),
            ),
      ],
    );
  }
}
