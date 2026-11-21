import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/repositories/sales_orders_controller.dart';
import 'package:fscm_mobile/features/common/notifications/notification_bell_button.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/chip_filter_bar.dart';
import 'package:fscm_mobile/shared/widgets/empty_state.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/order_widgets.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';

/// "Đơn hàng": own orders + orders of the same group, including offline
/// orders that are still on the device.
class SalesOrdersScreen extends ConsumerStatefulWidget {
  const SalesOrdersScreen({super.key});

  @override
  ConsumerState<SalesOrdersScreen> createState() => _SalesOrdersScreenState();
}

class _SalesOrdersScreenState extends ConsumerState<SalesOrdersScreen> {
  SalesOrderGroup _filter = SalesOrderGroup.all;

  /// Sent to the server; changing it restarts paging at page 1.
  String _query = '';
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  SalesOrdersQuery get _key => SalesOrdersQuery(search: _query, group: _filter);

  Widget _offlineBanner() => const InfoBanner(
        tone: StatusTone.warning,
        icon: Icons.cloud_off,
        text: 'Đang ngoại tuyến - chỉ hiển thị các đơn lưu trên máy.',
      );

  /// Shown while a status the Backend cannot filter is assembled: the list
  /// is incomplete until the last page has arrived.
  Widget _scanBanner(SalesOrdersState s) => InfoBanner(
        icon: Icons.sync,
        text: 'Đang tải đầy đủ đơn để lọc theo trạng thái '
            '(${s.server.length}/${s.totalCount}). Danh sách chưa đầy đủ.',
      );

  bool _hasFooter(SalesOrdersState s) =>
      s.hasMore || s.loadingMore || s.moreError != null || s.server.isNotEmpty;

  Widget _footer(SalesOrdersState s, bool filteredEmpty) {
    if (s.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator(strokeWidth: 3)),
      );
    }
    final notifier = ref.read(salesOrdersProvider(_key).notifier);
    final end = !s.hasMore && s.moreError == null;
    return Column(
      children: <Widget>[
        if (filteredEmpty && !end)
          const EmptyState(title: 'Chưa có đơn phù hợp trong dữ liệu đã tải.'),
        if (filteredEmpty && end)
          const EmptyState(title: 'Không có đơn phù hợp.'),
        if (_filter == SalesOrderGroup.offline && s.hasMore)
          const Text(
              'Gồm đơn ngoại tuyến lưu trên máy và các đơn đã tải; '
              'đơn ngoại tuyến đã đồng bộ chưa tải sẽ hiện khi tải thêm.',
              style: AppText.muted),
        if (s.moreError != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: InfoBanner(text: s.moreError!),
          ),
        if (end)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Text('Đã hiển thị tất cả đơn', style: AppText.muted),
          )
        else
          OutlinedButton(
            onPressed: notifier.loadMore,
            child: Text(s.moreError != null ? 'Thử lại' : 'Tải thêm đơn'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(salesOrdersProvider(_key));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đơn hàng'),
        actions: const <Widget>[
          Padding(
              padding: EdgeInsets.only(right: AppSpacing.xs),
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
          // Toolbar strip (prototype: white band under the header holding
          // the search field and the status filters).
          Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            padding: const EdgeInsets.only(bottom: AppSpacing.s10),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                      AppSpacing.md, AppSpacing.lg, AppSpacing.s10),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Tìm mã đơn hoặc tên cửa hàng',
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
                ChipFilterBar<SalesOrderGroup>(
                  options: const <ChipOption<SalesOrderGroup>>[
                    ChipOption<SalesOrderGroup>(SalesOrderGroup.all, 'Tất cả'),
                    ChipOption<SalesOrderGroup>(
                        SalesOrderGroup.pending, 'Chờ xử lý'),
                    ChipOption<SalesOrderGroup>(
                        SalesOrderGroup.inProgress, 'Đang xử lý'),
                    ChipOption<SalesOrderGroup>(
                        SalesOrderGroup.delivered, 'Đã giao'),
                    ChipOption<SalesOrderGroup>(
                        SalesOrderGroup.rejected, 'Từ chối / hủy'),
                    ChipOption<SalesOrderGroup>(
                        SalesOrderGroup.offline, 'Đơn ngoại tuyến'),
                  ],
                  selected: _filter,
                  onSelected: (v) => setState(() => _filter = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncBody<SalesOrdersState>(
              value: value,
              onRetry: () =>
                  ref.read(salesOrdersProvider(_key).notifier).refresh(),
              builder: (result) {
                final list = result.orders;
                final banner =
                    (result.offlineOnly ? 1 : 0) + (result.scanning ? 1 : 0);
                final footer = _hasFooter(result) ? 1 : 0;
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(salesOrdersProvider(_key).notifier).refresh(),
                  child: list.isEmpty && footer == 0
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: <Widget>[
                              if (result.offlineOnly) _offlineBanner(),
                              const SizedBox(height: 80),
                              const EmptyState(title: 'Không có đơn phù hợp.'),
                            ])
                      : NotificationListener<ScrollNotification>(
                          onNotification: (n) {
                            // Near the end: ask for the next page. The
                            // controller ignores the call while one is running.
                            // Current state, not the build-time capture: a
                            // failure must stop the automatic requests.
                            final now =
                                ref.read(salesOrdersProvider(_key)).valueOrNull;
                            if (n.metrics.extentAfter < 300 &&
                                now != null &&
                                now.hasMore &&
                                now.moreError == null) {
                              ref
                                  .read(salesOrdersProvider(_key).notifier)
                                  .loadMore();
                            }
                            return false;
                          },
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                                AppSpacing.sm, AppSpacing.lg, 90),
                            itemCount: banner + list.length + footer,
                            itemBuilder: (context, i) {
                              if (i < banner) {
                                return result.offlineOnly && i == 0
                                    ? _offlineBanner()
                                    : _scanBanner(result);
                              }
                              final index = i - banner;
                              if (index < list.length) {
                                return SalesOrderTile(order: list[index]);
                              }
                              return _footer(result, list.isEmpty);
                            },
                          ),
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
      onTap: () => context.push(AppRoutes.salesOrderDetail(
          o.syncStatus != null && o.offlineCode.isNotEmpty
              ? o.offlineCode
              : o.isOffline || o.id.isEmpty
                  ? code
                  : o.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header: order code + status chip (prototype card header).
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              Text(code, style: AppText.strong),
              OrderStatusChip(o),
            ],
          ),
          if (o.offlineCode.isNotEmpty && o.offlineCode != code)
            Text('Mã trên máy: ${o.offlineCode}', style: AppText.mutedSmall),
          const SizedBox(height: AppSpacing.sm),
          Text.rich(
            TextSpan(
              text: o.retailerName,
              children: <InlineSpan>[
                if (o.retailerCode.isNotEmpty)
                  TextSpan(
                      text: ' · ${o.retailerCode}',
                      style: AppText.mutedSmall.copyWith(fontSize: 12)),
              ],
            ),
            style: AppText.bodyMedium,
          ),
          if (o.itemsSummary.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
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
                child: Text(AppDates.timeDay(o.createdAt),
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
          if (o.isOffline || o.promoChanged) ...<Widget>[
            const SizedBox(height: AppSpacing.s10),
            Wrap(
              spacing: AppSpacing.s6,
              runSpacing: AppSpacing.s6,
              children: <Widget>[
                if (o.isOffline)
                  const StatusChip(label: 'Offline', tone: StatusTone.neutral),
                if (o.promoChanged)
                  const StatusChip(
                      label: 'KM thay đổi', tone: StatusTone.warning),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
