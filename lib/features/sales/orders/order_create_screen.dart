import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/network/network_monitor.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/order_availability.dart';
import 'package:fscm_mobile/shared/widgets/warehouse_stock_list.dart';
import 'package:fscm_mobile/data/models/price_quote.dart';
import 'package:fscm_mobile/data/models/product.dart';
import 'package:fscm_mobile/data/models/retailer.dart';
import 'package:fscm_mobile/data/pricing/order_limits.dart';
import 'package:fscm_mobile/data/remote/products_api.dart';
import 'package:fscm_mobile/data/remote/orders_api.dart';
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
import 'package:fscm_mobile/data/repositories/retailer_repository.dart';

final _orderAvailabilityProvider = FutureProvider.autoDispose
    .family<Map<String, ProductAvailability>, String>((ref, retailerId) async {
  ref.watch(dataVersionProvider);
  final catalog = await ref.watch(catalogProvider.future);
  return ref.watch(ordersApiProvider).availabilityByWarehouse(
      retailerId, catalog.products.map((product) => product.id).toList());
});

/// Create an order for one retailer. Works offline: the discount is
/// estimated from the cached promotions and the order is stored in the
/// local queue (`OFF-{device}-{0000}`); online it goes straight to
/// `POST /orders`.
class OrderCreateScreen extends ConsumerStatefulWidget {
  const OrderCreateScreen({super.key, this.retailerCode});

  final String? retailerCode;

  @override
  ConsumerState<OrderCreateScreen> createState() => _OrderCreateScreenState();
}

class _OrderCreateScreenState extends ConsumerState<OrderCreateScreen> {
  final Map<String, int> _cart = <String, int>{};
  String _query = '';
  late final String _clientOrderKey = const Uuid().v4();

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(syncServiceProvider.notifier).refreshSnapshot());
  }

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
          final retailer = widget.retailerCode == null
              ? (data.retailers.length == 1 ? data.retailers.single : null)
              : data.retailer(widget.retailerCode!);
          if (retailer == null) {
            return const EmptyState(
                title: 'Không tìm thấy điểm bán',
                message: 'Đồng bộ lại danh sách điểm bán rồi thử lại.');
          }
          if (user?.role == UserRole.sales &&
              !online &&
              retailer.status != 'Active') {
            return const EmptyState(
              icon: Icons.lock_outline,
              title: 'Chưa thể chuẩn bị đơn offline',
              message: 'Theo snapshot hiện có, điểm bán chưa hoạt động. '
                  'Kết nối mạng và cập nhật dữ liệu để kiểm tra lại.',
            );
          }
          if (!online) return _body(context, data, retailer, online);
          final availability =
              ref.watch(_orderAvailabilityProvider(retailer.id));
          return AsyncBody<Map<String, ProductAvailability>>(
            value: availability,
            onRetry: () =>
                ref.invalidate(_orderAvailabilityProvider(retailer.id)),
            builder: (quantities) => _body(
              context,
              CatalogData(
                retailers: data.retailers,
                products: data.products,
                prices: data.prices,
                promotions: data.promotions,
                stock: quantities
                    .map((sku, stock) => MapEntry(sku, stock.quantity)),
                lastSyncAt: data.lastSyncAt,
                snapshot: data.snapshot,
              ),
              retailer,
              online,
              availability: quantities,
            ),
          );
        },
      ),
    );
  }

  Widget _body(
      BuildContext context, CatalogData data, Retailer retailer, bool online,
      {Map<String, ProductAvailability>? availability}) {
    final isRetailer =
        ref.watch(currentUserProvider)?.role == UserRole.retailer;
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
                InfoBanner(
                  tone: StatusTone.warning,
                  icon: Icons.cloud_off,
                  title: 'Đang offline',
                  text: isRetailer
                      ? 'Kết nối mạng để xem giá khuyến mãi và gửi đơn hàng.'
                      : 'Đơn được lưu trên máy, khuyến mãi chỉ là tạm tính. Khi có mạng hệ thống sẽ tính lại, phân bổ kho và quyết định cuối cùng.',
                ),
              InfoBanner(
                text: online
                    ? 'Hiển thị tồn đủ điều kiện của từng kho. Khi gửi đơn, hệ thống tự chọn kho và batch, có thể lấy từ nhiều kho. Số lượng được kiểm tra lại khi gửi.'
                    : 'Tồn tham khảo lúc ${_stamp(data)}. Hệ thống sẽ kiểm tra lại điều kiện giao khi có mạng.',
              ),
              TextField(
                decoration: const InputDecoration(
                    hintText: 'Tìm sản phẩm', prefixIcon: Icon(Icons.search)),
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
              ),
              const SizedBox(height: 10),
              for (final p in products)
                _productRow(p, data, quote, availability?[p.sku]),
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

  Widget _productRow(Product p, CatalogData data, PriceQuote quote,
      ProductAvailability? availability) {
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
          if (availability != null)
            WarehouseStockList(warehouses: availability.warehouses),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  max == 0
                      ? 'Chưa đủ hàng để đặt theo bội 10 thùng'
                      : 'Chọn số lượng · bội 10 thùng',
                  style: TextStyle(
                      color: max == 0 ? AppColors.danger : AppColors.textMuted,
                      fontSize: 13),
                ),
              ),
              if (max > 0)
                QuantityStepper(
                  value: qty,
                  step: OrderLimits.step,
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

  Future<void> _ensureSalesOrderEligibility(
    Retailer retailer,
  ) async {
    final user = ref.read(currentUserProvider);

    if (user == null) {
      throw const ApiException(
        kind: ApiErrorKind.unauthorized,
        message: 'Vui lòng đăng nhập lại.',
      );
    }

    // Retailer self-order uses its existing backend authorization.
    if (user.role == UserRole.retailer) return;

    if (user.role != UserRole.sales) {
      throw const ApiException(
        kind: ApiErrorKind.forbidden,
        message: 'Tài khoản không được sử dụng luồng đặt hàng Sales.',
      );
    }

    final result = await ref.read(retailerRepositoryProvider).orderEligibility(
          retailer.id,
          salesUserId: user.id,
        );

    if (!mounted) {
      throw const ApiException(
        kind: ApiErrorKind.forbidden,
        message: 'Màn hình đặt hàng đã đóng.',
      );
    }

    if (ref.read(currentUserProvider)?.id != user.id) {
      throw const ApiException(
        kind: ApiErrorKind.forbidden,
        message: 'Phiên đăng nhập đã thay đổi. Vui lòng mở lại đơn.',
      );
    }

    if (!result.isEligible) {
      throw ApiException(
        kind: ApiErrorKind.forbidden,
        message: result.denialMessage,
      );
    }
  }

  Future<void> _review(
    CatalogData data,
    Retailer retailer,
    bool online,
  ) async {
    if (_busy) return;

    final user = ref.read(currentUserProvider);

    if (!online && user?.role == UserRole.retailer) {
      showAppSnack(
        context,
        'Cần kết nối mạng để gửi đơn và kiểm tra khuyến mãi.',
        error: true,
      );
      return;
    }

    if (!online &&
        user?.role == UserRole.sales &&
        retailer.status != 'Active') {
      showAppSnack(
        context,
        'Điểm bán chưa hoạt động theo snapshot hiện có. '
        'Kết nối mạng để kiểm tra lại.',
        error: true,
      );
      return;
    }

    final lines = _lines;
    var quote = data.quote(lines, retailer.code);
    var estimated = true;

    if (online) {
      setState(() => _busy = true);

      try {
        await _ensureSalesOrderEligibility(retailer);

        if (!mounted) return;

        try {
          quote = await ref.read(productsApiProvider).quote(
                retailerId: retailer.id,
                lines: lines
                    .map(
                      (line) => CartLine(
                        productId: data.product(line.sku)?.id ?? '',
                        sku: line.sku,
                        qty: line.qty,
                      ),
                    )
                    .toList(),
              );
          estimated = false;
        } on ApiException {
          // Preserve the existing quote fallback behavior.
          // Eligibility failures are handled by the outer catch.
        }
      } catch (error) {
        if (mounted) {
          showAppSnack(
            context,
            ApiException.describe(error),
            error: true,
          );
        }
        return;
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }

    if (!mounted) return;

    final confirmed = await showModalBottomSheet<bool>(
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

    if (confirmed != true || !mounted) return;

    await _submit(data, retailer);
  }

  Future<void> _submit(CatalogData data, Retailer retailer) async {
    final repo = ref.read(orderRepositoryProvider);
    final productsBySku = <String, Product>{
      for (final p in data.products) p.sku: p
    };
    final lines = _lines
        .map((line) => CartLine(
              productId: productsBySku[line.sku]?.id ?? '',
              sku: line.sku,
              qty: line.qty,
            ))
        .toList();
    if (retailer.id.isEmpty || lines.any((line) => line.productId.isEmpty)) {
      showAppSnack(context,
          'Dữ liệu Retailer/SKU chưa có ID từ máy chủ. Hãy đồng bộ lại danh mục.',
          error: true);
      return;
    }
    final online = ref.read(networkMonitorProvider).online;
    setState(() => _busy = true);
    try {
      var code = '';
      var message = '';
      Future<void> saveOffline(String notice) async {
        final entry =
            await repo.createOffline(retailer: retailer, lines: lines);
        code = entry.localCode;
        message = notice;
      }

      if (online) {
        try {
          await _ensureSalesOrderEligibility(retailer);

          if (!mounted) return;

          final quantities = await ref.read(ordersApiProvider).availability(
              retailer.id, lines.map((line) => line.productId).toList());
          if (lines.any((line) =>
              line.qty > OrderLimits.maxQty(quantities[line.sku] ?? 0))) {
            ref.invalidate(_orderAvailabilityProvider(retailer.id));
            if (mounted) {
              setState(() {
                for (final entry in _cart.entries.toList()) {
                  final maximum =
                      OrderLimits.maxQty(quantities[entry.key] ?? 0);
                  if (entry.value > maximum) {
                    _cart[entry.key] = maximum;
                  }
                }
              });
              showAppSnack(context,
                  'Tồn đủ điều kiện giao vừa thay đổi. Hãy điều chỉnh số lượng và thử lại.',
                  error: true);
            }
            return;
          }
          final order = await repo.createOnline(NewOrderRequest(
            clientOrderKey: _clientOrderKey,
            retailerId: retailer.id,
            lines: lines,
            deliveryAddress: retailer.address,
          ));
          code = order.id;
          message = order.status.isRejectedOrCancelled
              ? 'Đơn ${order.code} bị từ chối: ${order.rejectReason}'
              : 'Đã tạo SO ${order.code}. Hệ thống đang phân bổ và sẽ gửi báo giá cho Retailer.';
        } on ApiException catch (e) {
          if (!e.isNetwork ||
              ref.read(currentUserProvider)?.role == UserRole.retailer) {
            rethrow;
          }
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
      context.pushReplacement(
          ref.read(currentUserProvider)?.role == UserRole.retailer
              ? AppRoutes.rtOrderDetail(code)
              : AppRoutes.salesOrderDetail(code));
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
