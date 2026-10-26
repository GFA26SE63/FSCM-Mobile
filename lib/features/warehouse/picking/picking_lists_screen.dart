import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/run_picking.dart';
import 'package:fscm_mobile/data/repositories/warehouse_repository.dart';
import 'package:fscm_mobile/features/common/notifications/notification_bell_button.dart';
import 'package:fscm_mobile/features/warehouse/picking/picking_list_tile.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/chip_filter_bar.dart';
import 'package:fscm_mobile/shared/widgets/empty_state.dart';

/// F43: the run picking sheets of this warehouse.
///
/// [closedOnly] gives the "Soạn xong" list. It filters on the sheet being
/// closed, not on anything having been issued - picking finishing and goods
/// leaving are two different steps, and a sheet can sit closed for a while
/// because another warehouse on the same orders is still short.
class PickingListsScreen extends ConsumerStatefulWidget {
  const PickingListsScreen({super.key, this.closedOnly = false});

  final bool closedOnly;

  @override
  ConsumerState<PickingListsScreen> createState() => _PickingListsScreenState();
}

class _PickingListsScreenState extends ConsumerState<PickingListsScreen> {
  SheetStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(pickingListsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.closedOnly ? 'Phiếu đã soạn xong' : 'Phiếu soạn'),
        actions: widget.closedOnly
            ? null
            : const <Widget>[
                Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: NotificationBellButton())
              ],
      ),
      body: Column(
        children: <Widget>[
          if (!widget.closedOnly) ...<Widget>[
            const SizedBox(height: 8),
            ChipFilterBar<SheetStatus?>(
              options: const <ChipOption<SheetStatus?>>[
                ChipOption<SheetStatus?>(null, 'Tất cả'),
                ChipOption<SheetStatus?>(SheetStatus.issued, 'Mới phát hành'),
                ChipOption<SheetStatus?>(SheetStatus.picking, 'Đang soạn'),
                ChipOption<SheetStatus?>(SheetStatus.ready, 'Soạn xong'),
                ChipOption<SheetStatus?>(
                    SheetStatus.needsHandling, 'Cần xử lý'),
              ],
              selected: _filter,
              onSelected: (v) => setState(() => _filter = v),
            ),
          ],
          Expanded(
            child: AsyncBody<List<RunPickingSheet>>(
              value: value,
              onRetry: () => ref.invalidate(pickingListsProvider),
              builder: (all) {
                final list = all.where((s) {
                  if (widget.closedOnly) return s.isClosed;
                  return _filter == null || s.status == _filter;
                }).toList();
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(pickingListsProvider),
                  child: list.isEmpty
                      ? ListView(children: const <Widget>[
                          SizedBox(height: 80),
                          EmptyState(
                              title: 'Không có phiếu soạn phù hợp.',
                              message:
                                  'Phiếu chỉ được phát hành sau khi Admin duyệt phương án của đợt và hệ thống giữ tồn xong.')
                        ])
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: <Widget>[
                            for (final s in list) PickingListTile(sheet: s)
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
