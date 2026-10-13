import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/features/common/notifications/notification_bell_button.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/chip_filter_bar.dart';
import 'package:fscm_mobile/shared/widgets/empty_state.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/order_widgets.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';

enum _OrderFilter { all, pending, inProgress, delivered, rejected, offline }

/// "Đơn hàng": own orders + orders of the same group, including offline
/// orders that are still on the device.
class SalesOrdersScreen extends ConsumerStatefulWidget {
  const SalesOrdersScreen({super.key});

  @override
  ConsumerState<SalesOrdersScreen> createState() => _SalesOrdersScreenState();
}

class _SalesOrdersScreenState extends ConsumerState<SalesOrdersScreen> {
  _OrderFilter _filter = _OrderFilter.all;
  String _query = '';

  bool _matches(Order o) {
    if (_query.isNotEmpty) {
      final hay =
          '${o.displayCode} ${o.retailerName} ${o.retailerCode}'.toLowerCase();
      if (!hay.contains(_query)) return false;
    }
    switch (_filter) {
      case _OrderFilter.all:
        return true;
      case _OrderFilter.pending:
        return o.status == OrderStatus.pending;
      case _OrderFilter.inProgress:
        return o.status == OrderStatus.approved ||
            o.status == OrderStatus.picking ||
            o.status == OrderStatus.shipped ||
            o.status == OrderStatus.delivering;
      case _OrderFilter.delivered:
        return o.status == OrderStatus.delivered ||
            o.status == OrderStatus.completed;
      case _OrderFilter.rejected:
        return o.status == OrderStatus.rejected ||
            o.status == OrderStatus.cancelled;
      case _OrderFilter.offline:
        return o.isOffline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(ordersProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đơn hàng'),
        actions: const <Widget>[
          Padding(
              padding: EdgeInsets.only(right: 4),
              child: NotificationBellButton())
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.salesRetailers),
        icon: const Icon(Icons.add),
        label: const Text('Tạo đơn'),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Tìm mã đơn hoặc tên cửa hàng',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          ChipFilterBar<_OrderFilter>(
            options: const <ChipOption<_OrderFilter>>[
              ChipOption<_OrderFilter>(_OrderFilter.all, 'Tất cả'),
              ChipOption<_OrderFilter>(_OrderFilter.pending, 'Chờ duyệt'),
              ChipOption<_OrderFilter>(_OrderFilter.inProgress, 'Đang xử lý'),
              ChipOption<_OrderFilter>(_OrderFilter.delivered, 'Đã giao'),
              ChipOption<_OrderFilter>(_OrderFilter.rejected, 'Từ chối / hủy'),
              ChipOption<_OrderFilter>(_OrderFilter.offline, 'Đơn offline'),
            ],
            selected: _filter,
            onSelected: (v) => setState(() => _filter = v),
          ),
          Expanded(
            child: AsyncBody<OrderListResult>(
              value: value,
              onRetry: () => ref.invalidate(ordersProvider),
              builder: (result) {
                final list = result.orders.where(_matches).toList();
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(ordersProvider),
                  child: list.isEmpty
                      ? ListView(children: const <Widget>[
                          SizedBox(height: 80),
                          EmptyState(title: 'Không có đơn phù hợp.')
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                          itemCount: list.length + (result.offlineOnly ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (result.offlineOnly && i == 0) {
                              return const InfoBanner(
                                tone: StatusTone.warning,
                                icon: Icons.cloud_off,
                                text:
                                    'Đang offline - chỉ hiển thị các đơn lưu trên máy.',
                              );
                            }
                            final o = list[i - (result.offlineOnly ? 1 : 0)];
                            return SalesOrderTile(order: o);
                          },
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

/// One row of the orders list.
class SalesOrderTile extends StatelessWidget {
  const SalesOrderTile({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final code = o.displayCode;
    return AppCard(
      onTap: () => context.push(AppRoutes.salesOrderDetail(code)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(code,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              OrderStatusChip(o),
            ],
          ),
          const SizedBox(height: 2),
          Text('${o.retailerName} · ${AppDates.timeDay(o.createdAt)}',
              style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text(o.itemsSummary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Text(Money.format(o.finalAmount),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              if (o.isOffline)
                const StatusChip(label: 'Offline', tone: StatusTone.neutral),
              if (o.promoChanged) ...<Widget>[
                const SizedBox(width: 6),
                const StatusChip(
                    label: 'KM thay đổi', tone: StatusTone.warning),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
