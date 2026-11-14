import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/utils/clock.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/repositories/retailer_orders_controller.dart';
import 'package:fscm_mobile/features/common/notifications/notification_bell_button.dart';
import 'package:fscm_mobile/features/retailer/orders/widgets/retailer_todo_card.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/chip_filter_bar.dart';
import 'package:fscm_mobile/shared/widgets/empty_state.dart';
import 'package:fscm_mobile/shared/widgets/order_widgets.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';

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
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(retailerOrdersProvider(_query));
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/retailer/order/new'),
          icon: const Icon(Icons.add_shopping_cart),
          label: const Text('Đặt hàng'),
        ),
        appBar: AppBar(
          title: const Text('Đơn hàng'),
          actions: const <Widget>[NotificationBellButton()],
          bottom: const TabBar(
            tabs: <Widget>[Tab(text: 'Đang xử lý'), Tab(text: 'Lịch sử')],
          ),
        ),
        body: Column(
          children: <Widget>[
            const RetailerTodoCard(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Tìm mã đơn',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) {
                  _searchDebounce?.cancel();
                  _searchDebounce =
                      Timer(const Duration(milliseconds: 350), () {
                    if (mounted) {
                      setState(() => _query = v.trim().toLowerCase());
                    }
                  });
                },
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
              child: AsyncBody<RetailerOrdersState>(
                value: value,
                onRetry: () =>
                    ref.read(retailerOrdersProvider(_query).notifier).refresh(),
                builder: (result) {
                  // Search is performed by the server. Only the time range and
                  // status tabs filter the pages currently loaded on the device.
                  final all = result.orders.where(_inSpan).toList();
                  final active = all.where((o) => o.status.isActive).toList();
                  final history = all.where((o) => !o.status.isActive).toList();
                  return TabBarView(
                    children: <Widget>[
                      _OrderList(
                          orders: active,
                          empty:
                              'Không có đơn đang xử lý trong dữ liệu đã tải.',
                          search: _query,
                          state: result),
                      _OrderList(
                          orders: history,
                          empty: 'Chưa có đơn lịch sử trong dữ liệu đã tải.',
                          search: _query,
                          state: result),
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
  const _OrderList(
      {required this.orders,
      required this.empty,
      required this.search,
      required this.state});

  final List<Order> orders;
  final String empty;
  final String search;
  final RetailerOrdersState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(retailerOrdersProvider(search).notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text('Đã tải ${state.orders.length}/${state.totalCount} đơn'
              '${search.isEmpty ? '' : ' khớp mã tìm kiếm'}. '
              'Tab trạng thái và bộ lọc thời gian chỉ áp dụng trên các đơn đã tải.'),
          if (state.hasMore && orders.isEmpty)
            const InfoBanner(
                text: 'Vẫn còn đơn chưa tải. Chọn "Tải thêm đơn" để tiếp tục '
                    'kiểm tra kết quả trong tab và khoảng thời gian này.'),
          if (orders.isEmpty) EmptyState(title: empty),
          for (final order in orders) RtOrderTile(order: order),
          if (state.moreError != null) InfoBanner(text: state.moreError!),
          if (state.hasMore)
            OutlinedButton(
              onPressed: state.loadingMore
                  ? null
                  : () => ref
                      .read(retailerOrdersProvider(search).notifier)
                      .loadMore(),
              child: Text(state.loadingMore ? 'Đang tải...' : 'Tải thêm đơn'),
            ),
        ],
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
      onTap: () => context.push(AppRoutes.rtOrderDetail(o.id)),
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
