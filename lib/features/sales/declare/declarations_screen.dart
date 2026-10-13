import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/retailer_registration.dart';
import 'package:fscm_mobile/data/repositories/retailer_repository.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/empty_state.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/kv_row.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';
import 'package:fscm_mobile/shared/widgets/timeline_list.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';

/// "Khai báo retailer": my declarations (KB-0000) and their approval state.
class DeclarationsScreen extends ConsumerWidget {
  const DeclarationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(registrationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Khai báo retailer')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.salesDeclare),
        icon: const Icon(Icons.add),
        label: const Text('Khai báo mới'),
      ),
      body: AsyncBody<List<RetailerRegistration>>(
        value: value,
        onRetry: () => ref.invalidate(registrationsProvider),
        builder: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          children: <Widget>[
            const InfoBanner(
                text: 'Admin / Operator duyệt và cấp mã điểm bán 8 số.'),
            if (list.isEmpty)
              const EmptyState(title: 'Không có khai báo phù hợp.'),
            for (final r in list) _Tile(reg: r),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.reg});

  final RetailerRegistration reg;

  @override
  Widget build(BuildContext context) {
    final r = reg;
    return AppCard(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: Row(
            children: <Widget>[
              Expanded(
                  child: Text('${r.code} · ${r.name}',
                      style: const TextStyle(fontWeight: FontWeight.w800))),
              StatusChip(label: r.status.label, tone: r.status.tone),
            ],
          ),
          subtitle: Text('${r.address}\n${r.areaName}',
              style:
                  const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
          children: <Widget>[
            if (r.status == RegistrationStatus.rejected)
              InfoBanner(
                  tone: StatusTone.danger,
                  title: 'Lý do từ chối',
                  text: r.reason),
            if (r.status == RegistrationStatus.waiting)
              const InfoBanner(
                  text:
                      'Đang chờ Admin / Operator kiểm tra thông tin. Chưa đặt hàng được cho điểm bán này.'),
            KvRow('Mã điểm bán', r.retailerCode.isEmpty ? '—' : r.retailerCode),
            KvRow('Người liên hệ', r.contactName),
            KvRow('Số điện thoại', r.phone),
            KvRow('Loại hình',
                '${r.potential.kind} · quy mô ${r.potential.size} · ${r.potential.areaM2} m²'),
            KvRow('Tủ mát', '${r.potential.fridges}'),
            KvRow('Doanh thu dự báo',
                '${Money.format(r.potential.forecastRevenue)} / tháng'),
            KvRow('Khả năng nhập',
                '${r.potential.capacityCases} thùng / tháng · ${r.potential.frequency}'),
            if (r.potential.grade.isNotEmpty)
              KvRow('Xếp loại tiềm năng', r.potential.grade),
            const SizedBox(height: 8),
            TimelineList(r.timeline),
          ],
        ),
      ),
    );
  }
}
