import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/utils/clock.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/features/common/notifications/notification_bell_button.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/chip_filter_bar.dart';
import 'package:fscm_mobile/shared/widgets/empty_state.dart';
import 'package:fscm_mobile/shared/widgets/order_widgets.dart';

enum _Span { all, week, month }

/// Retailer "Đơn hàng": tabs "Đang xử lý" / "Lịch sử", search and time chips.
class RtOrdersScreen extends ConsumerStatefulWidget {
  const RtOrdersScreen({super.key});

  @override
  ConsumerState<RtOrdersScreen> createState() => _RtOrdersScreenState();
}

class _RtOrdersScreenState extends ConsumerState<RtOrdersScreen> {
  String _query = '';
  _Span _span = _Span.all;

  bool _inSpan(Order o) {
    switch (_span) {
      case _Span.all:
        return true;
      case _Span.week:
        return AppDates.daysBetween(o.createdAt, AppClock.now()) <= 7;
      case _Span.month:
        return AppDates.daysBetween(o.createdAt, AppClock.now()) <= 30;
    }
  }

  bool _matches(Order o) {
    if (!_inSpan(o)) return false;
    if (_query.isEmpty) return true;
    final hay = '${o.code} ${o.itemsSummary}'.toLowerCase();
    return hay.contains(_query);
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(ordersProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Đơn hàng'),
          actions: const <Widget>[NotificationBellButton()],
          bottom: const TabBar(
            tabs: <Widget>[Tab(text: 'Đang xử lý'), Tab(text: 'Lịch sử')],
          ),
        ),
        body: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Tìm mã đơn hoặc sản phẩm',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
              ),
            ),
            ChipFilterBar<_Span>(
              selected: _span,
              onSelected: (v) => setState(() => _span = v),
              options: const <ChipOption<_Span>>[
                ChipOption(_Span.all, 'Tất cả'),
                ChipOption(_Span.week, '7 ngày'),
                ChipOption(_Span.month, '30 ngày'),
              ],
            ),
            Expanded(
              child: AsyncBody<OrderListResult>(
                value: value,
                onRetry: () => ref.invalidate(ordersProvider),
                builder: (result) {
                  final all = result.orders.where(_matches).toList();
                  final active = all.where((o) => o.status.isActive).toList();
                  final history = all.where((o) => !o.status.isActive).toList();
                  return TabBarView(
                    children: <Widget>[
                      _OrderList(
                          orders: active, empty: 'Không có đơn đang xử lý.'),
                      _OrderList(
                          orders: history, empty: 'Chưa có đơn trong lịch sử.'),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderList extends ConsumerWidget {
  const _OrderList({required this.orders, required this.empty});

  final List<Order> orders;
  final String empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(ordersProvider),
      child: orders.isEmpty
          ? ListView(children: <Widget>[
              const SizedBox(height: 80),
              EmptyState(title: empty)
            ])
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (context, i) => RtOrderTile(order: orders[i]),
            ),
    );
  }
}

/// Row of the retailer order list (items, amount, payment, status).
class RtOrderTile extends StatelessWidget {
  const RtOrderTile({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final o = order;
    return AppCard(
      onTap: () => context.push(AppRoutes.rtOrderDetail(o.code)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                  child: Text(o.code,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15))),
              OrderStatusChip(o),
            ],
          ),
          Text(AppDates.timeDay(o.createdAt),
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
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  o.payment.labelWithTerm(o.creditTerm),
                  textAlign: TextAlign.right,
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          if (o.status.canConfirmReceipt) ...<Widget>[
            const SizedBox(height: 6),
            const Row(
              children: <Widget>[
                Icon(Icons.qr_code_scanner, size: 16, color: AppColors.primary),
                SizedBox(width: 6),
                Text('Quét QR để xác nhận nhận hàng',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
