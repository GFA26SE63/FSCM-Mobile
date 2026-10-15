import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/picking.dart';
import 'package:fscm_mobile/data/models/transfer.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/warehouse_repository.dart';
import 'package:fscm_mobile/features/common/notifications/notification_bell_button.dart';
import 'package:fscm_mobile/features/warehouse/picking/picking_list_tile.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/empty_state.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';

/// Warehouse Keeper home: picking workload and incoming transfers.
class WkHomeScreen extends ConsumerWidget {
  const WkHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final pickings =
        ref.watch(pickingListsProvider).valueOrNull ?? const <PickingList>[];
    final transfers =
        ref.watch(transfersProvider).valueOrNull ?? const <Transfer>[];
    final todo =
        pickings.where((p) => p.status != PickingStatus.shipped).toList();
    int count(PickingStatus s) => pickings.where((p) => p.status == s).length;
    final incoming =
        transfers.where((t) => t.status == TransferStatus.inTransit).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(user?.warehouseName ?? 'Kho'),
        actions: const <Widget>[
          Padding(
              padding: EdgeInsets.only(right: 4),
              child: NotificationBellButton())
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(pickingListsProvider);
          ref.invalidate(transfersProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text('Xin chào, ${user?.fullName ?? ''}',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Text('${user?.role.label ?? ''} · ${user?.scopeText ?? ''}',
                style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                    child: _Stat('Chờ lấy', count(PickingStatus.pending),
                        StatusTone.info)),
                const SizedBox(width: 10),
                Expanded(
                    child: _Stat('Đang lấy', count(PickingStatus.picking),
                        StatusTone.purple)),
                const SizedBox(width: 10),
                Expanded(
                    child: _Stat('Đã xuất', count(PickingStatus.shipped),
                        StatusTone.success)),
              ],
            ),
            const SizedBox(height: 10),
            AppCard(
              onTap: () => context.go(AppRoutes.wkTransfers),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.swap_horiz, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      incoming.isEmpty
                          ? 'Không có phiếu chuyển kho đang tới'
                          : '${incoming.length} phiếu chuyển kho đang tới - quét tem để nhận',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted),
                ],
              ),
            ),
            AppCard(
              onTap: () => context.push(AppRoutes.wkLabelLookup),
              child: const Row(
                children: <Widget>[
                  Icon(Icons.qr_code_2, color: AppColors.primary),
                  SizedBox(width: 12),
                  Expanded(
                      child: Text('Tra cứu tem',
                          style: TextStyle(fontWeight: FontWeight.w600))),
                  Icon(Icons.chevron_right, color: AppColors.textMuted),
                ],
              ),
            ),
            AppCard(
              onTap: () => context.push(AppRoutes.wkShipped),
              child: const Row(
                children: <Widget>[
                  Icon(Icons.local_shipping_outlined, color: AppColors.primary),
                  SizedBox(width: 12),
                  Expanded(
                      child: Text('Danh sách đã xuất kho',
                          style: TextStyle(fontWeight: FontWeight.w600))),
                  Icon(Icons.chevron_right, color: AppColors.textMuted),
                ],
              ),
            ),
            SectionTitle(
              'Picking list cần lấy',
              trailing: TextButton(
                  onPressed: () => context.go(AppRoutes.wkPicking),
                  child: const Text('Xem tất cả')),
            ),
            if (todo.isEmpty)
              const EmptyState(
                icon: Icons.task_alt,
                title: 'Không còn picking list cần lấy.',
                message:
                    'Picking list xuất hiện ngay khi Admin / Operator duyệt đơn. Mỗi đơn có một picking list cho mỗi kho (mã đơn + A, B, C...).',
              )
            else
              for (final p in todo.take(3)) PickingListTile(list: p),
            const SizedBox(height: 6),
            Text(
              'Cập nhật ${AppDates.timeDay(DateTime.now())}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.tone);

  final String label;
  final int value;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.tone(tone);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: c.background, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('$value',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: c.foreground)),
          Text(label, style: TextStyle(color: c.foreground, fontSize: 12.5)),
        ],
      ),
    );
  }
}
