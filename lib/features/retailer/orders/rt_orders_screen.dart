import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fscm_mobile/core/utils/focus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';

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
import 'package:fscm_mobile/shared/widgets/chip_filter_bar.dart';
import 'package:fscm_mobile/shared/widgets/empty_state.dart';
import 'package:fscm_mobile/shared/widgets/order_widgets.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';

enum _Span { all, week, month }

enum _OrderSort { newest, oldest, amountHighToLow, amountLowToHigh }

/// Retailer "Đơn hàng": tabs "Đang xử lý" / "Lịch sử", search and time chips.
class RtOrdersScreen extends ConsumerStatefulWidget {
  const RtOrdersScreen({super.key});

  @override
  ConsumerState<RtOrdersScreen> createState() => _RtOrdersScreenState();
}

class _RtOrdersScreenState extends ConsumerState<RtOrdersScreen>
    with SingleTickerProviderStateMixin {
  String _query = '';
  _Span _span = _Span.all;
  _OrderSort _sort = _OrderSort.newest;
  Timer? _searchDebounce;
  final TextEditingController _searchController = TextEditingController();
  late final TabController _tabs;
  final ScrollController _outer = ScrollController();
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this)..addListener(_onTab);
  }

  // Rebuild only when a tab change has settled (tap or swipe), not on every
  // frame of the swipe animation.
  void _onTab() {
    if (!_tabs.indexIsChanging && _tabs.index != _tabIndex) {
      setState(() => _tabIndex = _tabs.index);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _tabs
      ..removeListener(_onTab)
      ..dispose();
    _outer.dispose();
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

  int _compareOrders(Order a, Order b) {
    final comparison = switch (_sort) {
      _OrderSort.newest => b.createdAt.compareTo(a.createdAt),
      _OrderSort.oldest => a.createdAt.compareTo(b.createdAt),
      _OrderSort.amountHighToLow => b.finalAmount.compareTo(a.finalAmount),
      _OrderSort.amountLowToHigh => a.finalAmount.compareTo(b.finalAmount),
    };
    // Keep equal values deterministic so changing the toolbar never makes
    // otherwise identical rows jump around between tab switches.
    return comparison != 0 ? comparison : a.code.compareTo(b.code);
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
    return Scaffold(
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
        bottom: TabBar(
          controller: _tabs,
          tabs: const <Widget>[Tab(text: 'Đang xử lý'), Tab(text: 'Lịch sử')],
        ),
      ),
      // NestedScrollView = one vertical scroll: the header (overview card,
      // loyalty shortcut, search, time chips) scrolls away first, then the
      // order list of the selected tab; the TabBarView adds horizontal
      // swipe between "Đang xử lý" and "Lịch sử". Only the AppBar (with
      // the tabs) and the bottom bar stay fixed.
      body: RefreshIndicator(
        // The pull comes from the order list (it is the one that overscrolls),
        // so accept vertical notifications of any depth, but only while the
        // header is fully shown; horizontal tab swipes are ignored.
        notificationPredicate: (n) =>
            n.metrics.axis == Axis.vertical &&
            (!_outer.hasClients || _outer.offset <= 0),
        onRefresh: () =>
            ref.read(retailerOrdersProvider(_query).notifier).refresh(),
        child: NestedScrollView(
          controller: _outer,
          headerSliverBuilder: (context, innerBoxIsScrolled) =>
              <Widget>[SliverToBoxAdapter(child: _header())],
          body: value.when(
            skipLoadingOnRefresh: true,
            data: (result) => TabBarView(
              controller: _tabs,
              children: <Widget>[
                _orderPage(result, activeTab: true),
                _orderPage(result, activeTab: false),
              ],
            ),
            loading: () => _stateList(const CircularProgressIndicator(
              strokeWidth: 3,
              semanticsLabel: 'Đang tải',
            )),
            error: (error, _) => _stateList(EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Không tải được dữ liệu',
              message: ApiException.describe(error),
              action: OutlinedButton.icon(
                onPressed: () =>
                    ref.read(retailerOrdersProvider(_query).notifier).refresh(),
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            )),
          ),
        ),
      ),
    );
  }

  /// Loading / error content under the header, still part of the scroll.
  Widget _stateList(Widget child) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[Center(child: child)],
      );

  /// Overview card and the scrollable order-search toolbar.
  Widget _header() => Column(
        children: <Widget>[
          const RetailerTodoCard(),
          AppCard(
            margin: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      0, AppSpacing.md, 0, AppSpacing.sm),
                  child: TextField(
                    onTapOutside: releaseFocus,
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Tìm mã đơn',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Xóa tìm kiếm',
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchDebounce?.cancel();
                                setState(() {
                                  _searchController.clear();
                                  _query = '';
                                });
                              },
                            ),
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
                  padding: EdgeInsets.zero,
                  selected: _span,
                  onSelected: (v) => setState(() => _span = v),
                  options: const <ChipOption<_Span>>[
                    ChipOption(_Span.all, 'Tất cả'),
                    ChipOption(_Span.week, '7 ngày'),
                    ChipOption(_Span.month, '30 ngày'),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: DropdownButtonFormField<_OrderSort>(
                    value: _sort,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Sắp xếp',
                      prefixIcon: Icon(Icons.sort),
                    ),
                    items: const <DropdownMenuItem<_OrderSort>>[
                      DropdownMenuItem(
                        value: _OrderSort.newest,
                        child: Text('Đơn mới nhất'),
                      ),
                      DropdownMenuItem(
                        value: _OrderSort.oldest,
                        child: Text('Đơn cũ nhất'),
                      ),
                      DropdownMenuItem(
                        value: _OrderSort.amountHighToLow,
                        child: Text('Giá trị cao đến thấp'),
                      ),
                      DropdownMenuItem(
                        value: _OrderSort.amountLowToHigh,
                        child: Text('Giá trị thấp đến cao'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _sort = value);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _orderPage(RetailerOrdersState state, {required bool activeTab}) {
    // Search is performed by the server. Only the time range and status tabs
    // filter the pages currently loaded on the device.
    final all = state.orders.where(_inSpan).toList();
    final orders = (activeTab
        ? all.where((o) => o.status.isActive).toList()
        : all.where((o) => !o.status.isActive).toList())
      ..sort(_compareOrders);
    final empty = activeTab
        ? (state.hasMore
            ? 'Chưa thấy đơn đang xử lý trong dữ liệu đã tải.'
            : 'Không có đơn đang xử lý.')
        : (state.hasMore
            ? 'Chưa thấy đơn lịch sử trong dữ liệu đã tải.'
            : 'Chưa có đơn lịch sử.');
    _fillVisiblePage(
      state,
      activeTab: activeTab,
      visibleOrderCount: orders.length,
    );
    // The tabs and date range currently refine the loaded GraphQL page. Do
    // not auto-drain subsequent pages when this tab happens to have few rows:
    // that created a serial request waterfall on screen open. Pagination is
    // explicit (button) or user-driven (scroll near the end) below.
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        // Near the end of this list: next server page. The controller ignores
        // the call while a load runs; after a failure the "Tải thêm đơn"
        // button retries. Only this list's vertical scrolling counts (not the
        // header's, not the filter chips').
        final now = ref.read(retailerOrdersProvider(_query)).valueOrNull;
        if (n.metrics.axis == Axis.vertical &&
            n.metrics.extentAfter < 300 &&
            now != null &&
            now.hasMore &&
            now.moreError == null) {
          ref.read(retailerOrdersProvider(_query).notifier).loadMore();
        }
        return false;
      },
      child: ListView(
        key: PageStorageKey<String>(
            'rt-orders-${activeTab ? 'active' : 'history'}'),
        cacheExtent: 2000,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              'Đã tải ${state.orders.length}/${state.totalCount} đơn'
              '${_query.isEmpty ? '' : ' · kết quả tìm kiếm'}',
              style: AppText.mutedSmall,
            ),
          ),
          if (state.hasMore && orders.isEmpty)
            const InfoBanner(
                text: 'Còn đơn chưa tải. Cuộn xuống hoặc chọn “Tải thêm”.'),
          if (orders.isEmpty) EmptyState(title: empty),
          for (final order in orders) RtOrderTile(order: order),
          if (state.moreError != null) InfoBanner(text: state.moreError!),
          if (state.hasMore)
            OutlinedButton(
              onPressed: state.loadingMore
                  ? null
                  : () => ref
                      .read(retailerOrdersProvider(_query).notifier)
                      .loadMore(),
              child: Text(state.loadingMore ? 'Đang tải...' : 'Tải thêm đơn'),
            ),
        ],
      ),
    );
  }

  void _fillVisiblePage(
    RetailerOrdersState state, {
    required bool activeTab,
    required int visibleOrderCount,
  }) {
    // A server page can contain no rows for the active tab or date range.
    // Continue only until the visible tab has a complete page, never from the
    // offstage tab, and let the controller serialize every request.
    if (activeTab != (_tabIndex == 0) ||
        visibleOrderCount >= 10 ||
        !state.hasMore ||
        state.loadingMore ||
        state.moreError != null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(retailerOrdersProvider(_query).notifier).loadMore();
    });
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(o.code, style: AppText.strong),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(AppDates.timeDay(o.createdAt),
                        style: AppText.mutedSmall),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topRight,
                  child: OrderStatusChip(o),
                ),
              ),
            ],
          ),
          if (o.itemsSummary.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(o.itemsSummary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodySmall.copyWith(color: AppColors.textLabel)),
          ],
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s10, vertical: AppSpacing.sm),
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: AppRadius.smallAll,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('Thanh toán', style: AppText.mutedSmall),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(o.payment.labelWithTerm(o.creditTerm),
                          style: AppText.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      const Text('Tổng tiền', style: AppText.mutedSmall),
                      const SizedBox(height: AppSpacing.xxs),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(Money.format(o.finalAmount),
                            style: AppText.strong
                                .copyWith(color: AppColors.primary)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
