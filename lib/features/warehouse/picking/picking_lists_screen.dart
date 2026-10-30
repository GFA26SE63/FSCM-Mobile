import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/picking.dart';
import 'package:fscm_mobile/data/repositories/warehouse_repository.dart';
import 'package:fscm_mobile/features/common/notifications/notification_bell_button.dart';
import 'package:fscm_mobile/features/warehouse/picking/picking_list_tile.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/chip_filter_bar.dart';
import 'package:fscm_mobile/shared/widgets/empty_state.dart';

/// Picking lists screen matching `FSCM_Prototype_Prod_v1.1.html`
/// (`DEFS.warehouse` PICKING).
class PickingListsScreen extends ConsumerStatefulWidget {
  const PickingListsScreen({super.key, this.shippedOnly = false});

  final bool shippedOnly;

  @override
  ConsumerState<PickingListsScreen> createState() => _PickingListsScreenState();
}

class _PickingListsScreenState extends ConsumerState<PickingListsScreen> {
  PickingStatus? _filter;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(pickingListsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.shippedOnly ? 'Đã xuất kho' : 'Soạn hàng',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            if (!widget.shippedOnly)
              const Text(
                'Phần giao của Kho Thới An',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
        actions: widget.shippedOnly
            ? null
            : const <Widget>[
                Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: NotificationBellButton(),
                ),
              ],
      ),
      body: Column(
        children: <Widget>[
          if (!widget.shippedOnly) ...<Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Tìm mã phần giao hoặc tên điểm bán',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
              ),
            ),
            ChipFilterBar<PickingStatus?>(
              options: const <ChipOption<PickingStatus?>>[
                ChipOption<PickingStatus?>(null, 'Tất cả'),
                ChipOption<PickingStatus?>(PickingStatus.pending, 'Chưa soạn'),
                ChipOption<PickingStatus?>(PickingStatus.picking, 'Đang soạn'),
                ChipOption<PickingStatus?>(PickingStatus.shipped, 'Đã xuất'),
              ],
              selected: _filter,
              onSelected: (v) => setState(() => _filter = v),
            ),
          ],
          Expanded(
            child: AsyncBody<List<PickingList>>(
              value: value,
              onRetry: () => ref.invalidate(pickingListsProvider),
              builder: (all) {
                final list = all.where((p) {
                  if (widget.shippedOnly) {
                    return p.status == PickingStatus.shipped;
                  }
                  if (_filter != null && p.status != _filter) return false;
                  if (_query.isNotEmpty) {
                    final hay = '${p.code} ${p.retailerName}'.toLowerCase();
                    if (!hay.contains(_query)) return false;
                  }
                  return true;
                }).toList();
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(pickingListsProvider),
                  child: list.isEmpty
                      ? ListView(
                          children: const <Widget>[
                            SizedBox(height: 80),
                            EmptyState(title: 'Không có phần giao.'),
                          ],
                        )
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: <Widget>[
                            for (final p in list) PickingListTile(list: p),
                          ],
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
