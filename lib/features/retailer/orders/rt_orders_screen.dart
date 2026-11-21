import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/utils/clock.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/retailer_orders_controller.dart';
import 'package:fscm_mobile/features/common/notifications/notification_bell_button.dart';
import 'package:fscm_mobile/features/retailer/orders/widgets/retailer_todo_card.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';
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
        return AppDates.vietnamDaysBetween(o.createdAt, AppClock.now()) <= 7;
      case _Span.month:
        return AppDates.vietnamDaysBetween(o.createdAt, AppClock.now()) <= 30;
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(retailerOrdersProvider(_query));
    final user = ref.watch(currentUserProvider);
    final storeName = (user?.retailerName ?? '').trim();
    final storeCode = (user?.retailerCode ?? '').trim();
    final storeLine = <String>[
      if (storeName.isNotEmpty) storeName,
      if (storeCode.isNotEmpty) 'Mã $storeCode',
    ].join(' · ');
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: AppSpacing.lg,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Đơn hàng',
                  style: AppText.pageTitle.copyWith(color: AppColors.text)),
              if (storeLine.isNotEmpty)
                Text(storeLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.mutedSmall),
            ],
          ),
          actions: <Widget>[
            // Prototype header action "+ Đặt hàng" (same route as the old FAB).
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 124),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md)),
                    onPressed: () => context.push('/retailer/order/new'),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Đặt hàng'),
                  ),
                ),
              ),
            ),
            const NotificationBellButton(),
            const SizedBox(width: AppSpacing.xs),
          ],
          bottom: const TabBar(
            tabs: <Widget>[Tab(text: 'Đang xử lý'), Tab(text: 'Lịch sử')],
          ),
        ),
        body: Column(
          children: <Widget>[
            // Overview + toolbar scroll inside a bounded area so large fonts
            // never push the order list off screen.
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.5),
              child: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    const RetailerTodoCard(),
                    Container(
                      margin: const EdgeInsets.only(top: AppSpacing.md),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        border: Border.symmetric(
                            horizontal: BorderSide(color: AppColors.divider)),
                      ),
                      padding: const EdgeInsets.only(bottom: AppSpacing.s10),
                      child: Column(
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                                AppSpacing.md, AppSpacing.lg, AppSpacing.s10),
                            child: TextField(
                              decoration: const InputDecoration(
                                hintText: 'Tìm mã đơn',
                                prefixIcon: Icon(Icons.search),
                              ),
                              onChanged: (v) {
                                _searchDebounce?.cancel();
                                _searchDebounce = Timer(
                                    const Duration(milliseconds: 350), () {
                                  if (mounted) {
                                    setState(
                                        () => _query = v.trim().toLowerCase());
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          // Near the end: next page. The controller ignores the call while a
          // load runs; after a failure the "Tải thêm đơn" button retries.
          final now = ref.read(retailerOrdersProvider(search)).valueOrNull;
          if (n.metrics.extentAfter < 300 &&
              now != null &&
              now.hasMore &&
              now.moreError == null) {
            ref.read(retailerOrdersProvider(search).notifier).loadMore();
          }
          return false;
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                  'Đã tải ${state.orders.length}/${state.totalCount} đơn'
                  '${search.isEmpty ? '' : ' khớp mã tìm kiếm'}. '
                  'Tab trạng thái và bộ lọc thời gian chỉ áp dụng trên các đơn đã tải.',
                  style: AppText.mutedSmall),
            ),
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
          // Header: code + status chip (prototype order card).
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              Text(o.code, style: AppText.strong),
              OrderStatusChip(o),
            ],
          ),
          Text(AppDates.timeDay(o.createdAt), style: AppText.mutedSmall),
          if (o.itemsSummary.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(o.itemsSummary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodySmall.copyWith(color: AppColors.textLabel)),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Text(o.payment.labelWithTerm(o.creditTerm),
                    style: AppText.mutedSmall),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child:
                      Text(Money.format(o.finalAmount), style: AppText.strong),
                ),
              ),
            ],
          ),
          if (o.status.canConfirmReceipt) ...<Widget>[
            const SizedBox(height: AppSpacing.s10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s10, vertical: AppSpacing.sm),
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: AppRadius.smallAll,
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.qr_code_scanner,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.s6),
                  Expanded(
                    child: Text('Quét QR để xác nhận nhận hàng',
                        style: AppText.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
