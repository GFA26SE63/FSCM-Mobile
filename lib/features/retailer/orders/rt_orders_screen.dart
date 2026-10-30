import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/utils/clock.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/product.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/catalog_repository.dart';
import 'package:fscm_mobile/data/repositories/loyalty_repository.dart';
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

/// Retailer "Đơn hàng" screen matching `FSCM_Prototype_Prod_v1.1.html`
/// (`DEFS.retailer` ORDERS).
class RtOrdersScreen extends ConsumerStatefulWidget {
  const RtOrdersScreen({super.key});

  @override
  ConsumerState<RtOrdersScreen> createState() => _RtOrdersScreenState();
}

class _RtOrdersScreenState extends ConsumerState<RtOrdersScreen> {
  String _query = '';
  _Span _span = _Span.all;
  bool _showHistory = false;

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
    final user = ref.watch(currentUserProvider);
    final value = ref.watch(ordersProvider);
    final loyalty = ref.watch(loyaltyAccountProvider).valueOrNull;
    final catalog = ref.watch(catalogProvider).valueOrNull;
    final topProducts =
        (catalog?.products ?? const <Product>[]).take(3).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              user?.fullName ?? 'Tạp hóa Minh Châu',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            Text(
              'Mã ${user?.retailerCode ?? '10004127'} · Sales phụ trách: Nguyễn Văn An',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        actions: const <Widget>[NotificationBellButton()],
      ),
      body: AsyncBody<OrderListResult>(
        value: value,
        onRetry: () => ref.invalidate(ordersProvider),
        builder: (result) {
          final allOrders = result.orders;
          final validOrders = allOrders
              .where((o) =>
                  o.status != OrderStatus.rejected &&
                  o.status != OrderStatus.cancelled)
              .toList();
          final monthTotal =
              validOrders.fold<int>(0, (s, o) => s + o.finalAmount);
          final paidTotal = validOrders
              .where((o) => o.paid)
              .fold<int>(0, (s, o) => s + o.finalAmount);
          final unpaidTotal = validOrders
              .where((o) => !o.paid)
              .fold<int>(0, (s, o) => s + o.finalAmount);

          Order? deliveringOrder;
          for (final o in allOrders) {
            if (o.status == OrderStatus.delivering) {
              deliveringOrder = o;
              break;
            }
          }

          final filtered = allOrders.where(_matches).toList();
          final active = filtered.where((o) => o.status.isActive).toList();
          final history = filtered.where((o) => !o.status.isActive).toList();
          final currentList = _showHistory ? history : active;

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(ordersProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'Đơn tháng 9',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${validOrders.length} đơn',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Tổng ${Money.format(monthTotal)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => context.push(AppRoutes.rtPayments),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Text(
                                'Đã thanh toán ›',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                Money.format(paidTotal),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.success,
                                ),
                              ),
                              Text(
                                unpaidTotal > 0
                                    ? 'Còn nợ: ${Money.format(unpaidTotal)}'
                                    : 'Không còn công nợ',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: unpaidTotal > 0
                                      ? AppColors.warning
                                      : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => context.push(AppRoutes.rtLoyalty),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBF5E2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFEBD9A3)),
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE0A100),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.star_border,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '${loyalty?.balance ?? 412} điểm loyalty',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6B4E00),
                                ),
                              ),
                              const Text(
                                'Dùng điểm để đổi quà tặng',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF8B6914),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: Color(0xFF8B6914),
                        ),
                      ],
                    ),
                  ),
                ),
                if (topProducts.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Bán chạy khu vực Quận 12 · tháng 9',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        for (int i = 0;
                            i < topProducts.length;
                            i++) ...<Widget>[
                          if (i > 0)
                            const Divider(height: 12, color: Color(0xFFEEF0EC)),
                          Row(
                            children: <Widget>[
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: i == 0
                                      ? const Color(0xFFFEF3C7)
                                      : const Color(0xFFECEEF1),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: i == 0
                                        ? const Color(0xFF92400E)
                                        : const Color(0xFF374151),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  topProducts[i].name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                '${Money.format(topProducts[i].basePrice)}/${topProducts[i].pack}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (deliveringOrder != null) ...<Widget>[
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => context
                        .push(AppRoutes.rtOrderDetail(deliveringOrder!.code)),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1EAFE),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFD9C8FB)),
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.local_shipping_outlined,
                            color: Color(0xFF6D28D9),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Đơn ${deliveringOrder.code} đang giao',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF4C1D95),
                                  ),
                                ),
                                const Text(
                                  'Bấm để xem vận chuyển & quét QR nhận hàng',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF5B21B6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: Color(0xFF4C1D95),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _TabPillButton(
                        label: 'Đang xử lý (${active.length})',
                        active: !_showHistory,
                        onTap: () => setState(() => _showHistory = false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _TabPillButton(
                        label: 'Hoàn tất (${history.length})',
                        active: _showHistory,
                        onTap: () => setState(() => _showHistory = true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Tìm theo mã đơn',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                ),
                const SizedBox(height: 8),
                ChipFilterBar<_Span>(
                  selected: _span,
                  onSelected: (v) => setState(() => _span = v),
                  options: const <ChipOption<_Span>>[
                    ChipOption(_Span.all, 'Tất cả'),
                    ChipOption(_Span.week, '7 ngày'),
                    ChipOption(_Span.month, 'Tháng này'),
                  ],
                ),
                const SizedBox(height: 8),
                if (currentList.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 32),
                    child: EmptyState(title: 'Không có đơn phù hợp.'),
                  )
                else
                  for (final o in currentList) RtOrderTile(order: o),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TabPillButton extends StatelessWidget {
  const _TabPillButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.primary,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppColors.primary,
          ),
        ),
      ),
    );
  }
}

/// Row of the retailer order list matching `FSCM_Prototype_Prod_v1.1.html`.
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      o.code,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${AppDates.timeDay(o.createdAt)} · ${o.payment.labelWithTerm(o.creditTerm)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              OrderStatusChip(o),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                '${o.lines.length} mặt hàng',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                Money.format(o.finalAmount),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.primary,
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
                Text(
                  'Quét QR để xác nhận nhận hàng',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
