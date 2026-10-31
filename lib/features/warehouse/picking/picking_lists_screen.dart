import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/picking.dart';
import 'package:fscm_mobile/data/repositories/warehouse_repository.dart';
import 'package:fscm_mobile/features/common/notifications/notification_bell_button.dart';
import 'package:fscm_mobile/features/warehouse/picking/picking_list_tile.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/chip_filter_bar.dart';
import 'package:fscm_mobile/shared/widgets/empty_state.dart';

/// Picking lists of the warehouse. [shippedOnly] gives the "Đã xuất" list.
class PickingListsScreen extends ConsumerStatefulWidget {
  const PickingListsScreen({super.key, this.shippedOnly = false});

  final bool shippedOnly;

  @override
  ConsumerState<PickingListsScreen> createState() => _PickingListsScreenState();
}

class _PickingListsScreenState extends ConsumerState<PickingListsScreen> {
  PickingStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(pickingListsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.shippedOnly ? 'Đã xuất kho' : 'Picking list'),
        actions: widget.shippedOnly
            ? null
            : const <Widget>[
                Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: NotificationBellButton())
              ],
      ),
      body: Column(
        children: <Widget>[
          if (!widget.shippedOnly) ...<Widget>[
            const SizedBox(height: 8),
            ChipFilterBar<PickingStatus?>(
              options: const <ChipOption<PickingStatus?>>[
                ChipOption<PickingStatus?>(null, 'Tất cả'),
                ChipOption<PickingStatus?>(PickingStatus.pending, 'Chưa pick'),
                ChipOption<PickingStatus?>(PickingStatus.picking, 'Đang pick'),
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
                  return _filter == null || p.status == _filter;
                }).toList();
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(pickingListsProvider),
                  child: list.isEmpty
                      ? ListView(children: const <Widget>[
                          SizedBox(height: 80),
                          EmptyState(title: 'Không có picking list phù hợp.')
                        ])
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: <Widget>[
                            for (final p in list) PickingListTile(list: p)
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
