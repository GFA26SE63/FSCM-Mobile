import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/transfer.dart';
import 'package:fscm_mobile/data/repositories/warehouse_repository.dart';
import 'package:fscm_mobile/features/common/notifications/notification_bell_button.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/chip_filter_bar.dart';
import 'package:fscm_mobile/shared/widgets/empty_state.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';

enum _TransferFilter { all, nearExpiry, replenishment, received }

/// "Nhận hàng": transfers heading to this warehouse.
class TransfersScreen extends ConsumerStatefulWidget {
  const TransfersScreen({super.key});

  @override
  ConsumerState<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends ConsumerState<TransfersScreen> {
  _TransferFilter _filter = _TransferFilter.all;

  bool _match(Transfer t) {
    switch (_filter) {
      case _TransferFilter.all:
        return true;
      case _TransferFilter.nearExpiry:
        return t.isNearExpiry;
      case _TransferFilter.replenishment:
        return t.kind == TransferKind.replenishment;
      case _TransferFilter.received:
        return t.status == TransferStatus.received;
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(transfersProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhận hàng'),
        actions: const <Widget>[NotificationBellButton()],
      ),
      body: Column(
        children: <Widget>[
          const SizedBox(height: 8),
          ChipFilterBar<_TransferFilter>(
            selected: _filter,
            onSelected: (v) => setState(() => _filter = v),
            options: const <ChipOption<_TransferFilter>>[
              ChipOption(_TransferFilter.all, 'Tất cả'),
              ChipOption(_TransferFilter.nearExpiry, 'Luân chuyển cận hạn'),
              ChipOption(_TransferFilter.replenishment, 'Bổ sung tồn kho'),
              ChipOption(_TransferFilter.received, 'Đã nhận'),
            ],
          ),
          Expanded(
            child: AsyncBody<List<Transfer>>(
              value: value,
              onRetry: () => ref.invalidate(transfersProvider),
              builder: (all) {
                final list = all.where(_match).toList();
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.local_shipping_outlined,
                    title: 'Không có phiếu chuyển kho',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(transfersProvider),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    itemBuilder: (context, i) =>
                        TransferTile(transfer: list[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Row of a transfer slip (code, route, status, quantity).
class TransferTile extends StatelessWidget {
  const TransferTile({super.key, required this.transfer});

  final Transfer transfer;

  @override
  Widget build(BuildContext context) {
    final t = transfer;
    return AppCard(
      onTap: () => context.push(AppRoutes.wkTransferDetail(t.code)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(t.code,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              StatusChip(label: t.status.label, tone: t.status.tone),
            ],
          ),
          const SizedBox(height: 2),
          Text('${t.fromWarehouse} → ${t.toWarehouse}',
              style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              StatusChip(
                label: t.kind.label,
                tone: t.isNearExpiry ? StatusTone.warning : StatusTone.neutral,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${t.lines.length} dòng · ${t.totalQty} thùng · '
                  '${t.status == TransferStatus.received ? 'nhận ${AppDates.timeDay(t.receivedAt)}' : 'xuất ${AppDates.timeDay(t.shippedAt)}'}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
