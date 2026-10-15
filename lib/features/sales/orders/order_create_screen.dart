import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/network_monitor.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/price_quote.dart';
import 'package:fscm_mobile/data/models/product.dart';
import 'package:fscm_mobile/data/models/retailer.dart';
import 'package:fscm_mobile/data/remote/products_api.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/catalog_repository.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/features/sales/orders/order_confirm_sheet.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';
import 'package:fscm_mobile/shared/widgets/empty_state.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/online_chip.dart';
import 'package:fscm_mobile/shared/widgets/quantity_stepper.dart';
import 'package:fscm_mobile/sync/sync_service.dart';

/// Create an order for one retailer. Works offline: the discount is
/// estimated from the cached promotions and the order is stored in the
/// local queue (`OFF-{device}-{0000}`); online it goes straight to
/// `POST /orders`.
class OrderCreateScreen extends ConsumerStatefulWidget {
  const OrderCreateScreen({super.key, required this.retailerCode});

  final String retailerCode;

  @override
  ConsumerState<OrderCreateScreen> createState() => _OrderCreateScreenState();
}

class _OrderCreateScreenState extends ConsumerState<OrderCreateScreen> {
  final Map<String, int> _cart = <String, int>{};
  String _query = '';
  bool _busy = false;

  List<CartLine> get _lines => _cart.entries
      .where((e) => e.value > 0)
      .map((e) => CartLine(sku: e.key, qty: e.value))
      .toList();

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final user = ref.watch(currentUserProvider);
    final online = ref.watch(networkMonitorProvider).online;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo đơn hàng'),
        actions: const <Widget>[
          Padding(padding: EdgeInsets.only(right: 12), child: OnlineChip())
        ],
      ),
      body: AsyncBody<CatalogData>(
        value: catalog,
        onRetry: () => ref.invalidate(catalogProvider),
        builder: (data) {
          final retailer = data.retailer(widget.retailerCode);
          if (retailer == null) {
            return const EmptyState(
                title: 'Không tìm thấy điểm bán',
                message: 'Đồng bộ lại danh sách điểm bán rồi thử lại.');
          }
          if (retailer.areaCode != user?.areaCode) {
            return EmptyState(
              icon: Icons.lock_outline,
              title: 'Điểm bán ngoài khu vực',
              message:
                  '${retailer.name} thuộc khu vực ${retailer.areaName}. Bạn chỉ tạo được đơn cho điểm bán trong khu vực ${user?.areaName ?? ''}.',
            );
          }
          return _body(context, data, retailer, online);
        },
      ),
    );
  }

  Widget _body(
      BuildContext context, CatalogData data, Retailer retailer, bool online) {
    final products = data.products.where((p) {
      if (_query.isEmpty) return true;
      return p.name.toLowerCase().contains(_query) ||
          p.sku.toLowerCase().contains(_query);
    }).toList();
    final lines = _lines;
    final quote =
        lines.isEmpty ? PriceQuote.empty : data.quote(lines, retailer.code);
    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(retailer.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                    Text('Mã ${retailer.code} · ${retailer.address}',
                        style: const TextStyle(color: AppColors.textMuted)),
                    Text(
                      retailer.creditAllowed
                          ? 'Được mua công nợ ${retailer.creditTerm} ngày'
                          : 'Không mua công nợ',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (!online)
                const InfoBanner(
                  tone: StatusTone.warning,
                  icon: Icons.cloud_off,
                  title: 'Đang offline',
                  text:
                      'Đơn được lưu trên máy, khuyến mãi chỉ là tạm tính. Khi có mạng hệ thống sẽ tính lại, phân bổ kho và quyết định cuối cùng.',
                ),
              InfoBanner(
                text:
                    'Số lượng tối đa = tồn khả dụng (cập nhật lúc ${_stamp(data)}) trừ tồn đệm 20, làm tròn xuống bội số 10.',
              ),
              TextField(
                decoration: const InputDecoration(
                    hintText: 'Tìm sản phẩm', prefixIcon: Icon(Icons.search)),
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
              ),
              const SizedBox(height: 10),
              for (final p in products) _productRow(p, data, quote),
            ],
          ),
        ),
        _bottomBar(data, retailer, online, quote),
      ],
    );
  }

  String _stamp(CatalogData data) {
    final t = data.lastSyncAt;
    if (t == null) return 'chưa đồng bộ';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} ${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}';
  }

  Widget _productRow(Product p, CatalogData data, PriceQuote quote) {
    final max = data.maxQty(p.sku);
    final qty = _cart[p.sku] ?? 0;
    final line = quote.lines.where((l) => l.sku == p.sku).toList();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('${p.sku} · ${p.name}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          Text('${p.pack} · ${Money.format(data.unitPrice(p.sku))}/thùng',
              style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  max == 0
                      ? 'Không đủ tồn để đặt'
                      : 'Có thể đặt tối đa: $max thùng',
                  style: TextStyle(
                      color: max == 0 ? AppColors.danger : AppColors.textMuted,
                      fontSize: 13),
                ),
              ),
              if (max > 0)
                QuantityStepper(
                  value: qty,
                  step: 10,
                  max: max,
                  onChanged: (v) => setState(() => _cart[p.sku] = v),
                ),
            ],
          ),
          if (line.isNotEmpty && line.first.hasDiscount)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${line.first.promoId} · giảm ${Money.format(line.first.discount)}',
                style: const TextStyle(
                    color: AppColors.success, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bottomBar(
      CatalogData data, Retailer retailer, bool online, PriceQuote quote) {
    final count = _lines.length;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(count == 0 ? 'Giỏ hàng trống' : '$count sản phẩm',
                      style: const TextStyle(color: AppColors.textMuted)),
                  Text(
                    Money.format(quote.finalAmount),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  if (quote.discount > 0)
                    Text('Đã giảm ${Money.format(quote.discount)}',
                        style: const TextStyle(
                            color: AppColors.success, fontSize: 12.5)),
                ],
              ),
            ),
            SizedBox(
              width: 170,
              child: FilledButton(
                onPressed: (count == 0 || _busy)
                    ? null
                    : () => _review(data, retailer, online),
                child: Text(_busy ? 'Đang xử lý...' : 'Xem giỏ & đặt hàng'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _review(CatalogData data, Retailer retailer, bool online) async {
    final lines = _lines;
    var quote = data.quote(lines, retailer.code);
    var estimated = true;
    if (online) {
      setState(() => _busy = true);
      try {
        quote = await ref
            .read(productsApiProvider)
            .quote(retailerCode: retailer.code, lines: lines);
        estimated = false;
      } on ApiException {
        // Keep the local estimate.
      }
      if (!mounted) return;
      setState(() => _busy = false);
    }
    final payment = await showModalBottomSheet<PaymentMethod>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => OrderConfirmSheet(
        retailer: retailer,
        quote: quote,
        online: online,
        estimated: estimated,
      ),
    );
    if (payment == null || !mounted) return;
    await _submit(retailer, payment);
  }

  Future<void> _submit(Retailer retailer, PaymentMethod payment) async {
    final repo = ref.read(orderRepositoryProvider);
    final lines = _lines;
    final online = ref.read(networkMonitorProvider).online;
    setState(() => _busy = true);
    try {
      var code = '';
      var message = '';
      Future<void> saveOffline(String notice) async {
        final entry = await repo.createOffline(
            retailer: retailer, lines: lines, payment: payment);
        code = entry.localCode;
        message = notice;
      }

      if (online) {
        try {
          final order = await repo.createOnline(NewOrderRequest(
            retailerCode: retailer.code,
            lines: lines,
            payment: payment,
            creditTerm:
                payment == PaymentMethod.credit ? retailer.creditTerm : 0,
          ));
          code = order.code;
          message = order.status == OrderStatus.rejected
              ? 'Đơn ${order.code} bị từ chối: ${order.rejectReason}'
              : 'Đã tạo đơn ${order.code} - chờ duyệt.';
        } on ApiException catch (e) {
          if (!e.isNetwork) rethrow;
          await saveOffline(
              'Mất kết nối - đã lưu đơn trên máy, sẽ tự đồng bộ khi có mạng.');
        }
      } else {
        await saveOffline('Đã lưu đơn trên máy. Đơn sẽ được gửi khi có mạng.');
      }
      ref.read(dataVersionProvider.notifier).state++;
      if (online) {
        unawaited(ref.read(syncServiceProvider.notifier).refreshSnapshot());
      }
      if (!mounted) return;
      showAppSnack(context, message);
      context.pushReplacement(AppRoutes.salesOrderDetail(code));
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
