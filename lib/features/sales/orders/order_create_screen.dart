import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/network_monitor.dart';
import 'package:fscm_mobile/core/utils/clock.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/order_availability.dart';
import 'package:fscm_mobile/shared/widgets/warehouse_stock_list.dart';
import 'package:fscm_mobile/data/models/price_quote.dart';
import 'package:fscm_mobile/data/models/product.dart';
import 'package:fscm_mobile/data/models/retailer.dart';
import 'package:fscm_mobile/data/pricing/order_limits.dart';
import 'package:fscm_mobile/data/remote/orders_api.dart';
import 'package:fscm_mobile/data/remote/products_api.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/catalog_repository.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/features/sales/orders/order_confirm_sheet.dart';
import 'package:fscm_mobile/features/sales/products/product_detail_screen.dart';
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

final _orderAvailabilityProvider = FutureProvider.autoDispose
    .family<Map<String, ProductAvailability>, String>((ref, retailerId) async {
  ref.watch(dataVersionProvider);
  ref.watch(currentUserProvider);

  final api = ref.watch(ordersApiProvider);
  final catalog = await ref.watch(catalogProvider.future);

  return api.availabilityByWarehouse(
    retailerId,
    catalog.products.map((product) => product.id).toList(),
  );
});

class OrderCreateScreen extends ConsumerStatefulWidget {
  const OrderCreateScreen({
    super.key,
    this.retailerCode,
  });

  final String? retailerCode;

  @override
  ConsumerState<OrderCreateScreen> createState() => _OrderCreateScreenState();
}

class _OrderCreateScreenState extends ConsumerState<OrderCreateScreen> {
  final Map<String, int> _cart = <String, int>{};
  final String _clientOrderKey = const Uuid().v4();

  String _query = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();

    unawaited(
      Future<void>.microtask(() async {
        if (!mounted) {
          return;
        }

        await ref.read(syncServiceProvider.notifier).refreshSnapshot();
      }),
    );
  }

  List<CartLine> get _lines => _cart.entries
      .where((entry) => entry.value > 0)
      .map(
        (entry) => CartLine(
          sku: entry.key,
          qty: entry.value,
        ),
      )
      .toList();

  bool _isCurrentUser(String userId) =>
      mounted && ref.read(currentUserProvider)?.id == userId;

  /// Snapshot hiện có status trong raw payload.
  /// Không dùng areaCode để xác định quyền đặt hàng.
  bool _cachedRetailerIsActive(
    CatalogData data,
    Retailer retailer,
  ) {
    final rows = asMapList(data.snapshot?.raw['retailers']);

    return rows.any(
      (row) =>
          asStr(row['id']) == retailer.id && asStr(row['status']) == 'Active',
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final user = ref.watch(currentUserProvider);
    final online = ref.watch(networkMonitorProvider).online;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo đơn hàng'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: OnlineChip(),
          ),
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
              message: 'Cập nhật snapshot rồi mở lại màn đặt hàng.',
            );
          }

          if (user?.role == UserRole.sales &&
              !online &&
              !_cachedRetailerIsActive(data, retailer)) {
            return const EmptyState(
              icon: Icons.lock_outline,
              title: 'Chưa thể chuẩn bị đơn offline',
              message: 'Theo snapshot hiện có, điểm bán chưa có trạng thái '
                  'hoạt động hợp lệ. Kết nối mạng và cập nhật dữ liệu.',
            );
          }

          if (!online) {
            return _body(context, data, retailer, online);
          }

          // Giữ phần availability hiện có theo phạm vi đã thống nhất.
          final availability = ref.watch(
            _orderAvailabilityProvider(retailer.id),
          );

          return AsyncBody<Map<String, ProductAvailability>>(
            value: availability,
            onRetry: () {
              ref.invalidate(_orderAvailabilityProvider(retailer.id));
            },
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
    BuildContext context,
    CatalogData data,
    Retailer retailer,
    bool online, {
    Map<String, ProductAvailability>? availability,
  }) {
    final isRetailer =
        ref.watch(currentUserProvider)?.role == UserRole.retailer;

    final products = data.products.where((product) {
      return _query.isEmpty ||
          product.name.toLowerCase().contains(_query) ||
          product.sku.toLowerCase().contains(_query);
    }).toList();

    final lines = _lines;
    final quote =
        lines.isEmpty ? PriceQuote.empty : data.quote(lines, retailer.code);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      retailer.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Mã ${retailer.code} · ${retailer.address}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      retailer.creditAllowed
                          ? 'Kỳ hạn công nợ theo snapshot: '
                              '${retailer.creditTerm} ngày'
                          : 'Không mua công nợ theo snapshot',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
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
                      ? 'Kết nối mạng để kiểm tra giá và gửi đơn.'
                      : 'Giá và khuyến mãi chỉ là tạm tính. '
                          'Đơn lưu trên máy được backend kiểm tra lại '
                          'khi nhận.',
                ),
              InfoBanner(
                text: 'Snapshot lúc ${_stamp(data.lastSyncAt)}. '
                    'Giá và khuyến mãi trên giỏ được tính từ dữ liệu '
                    'đã lưu; chưa phải báo giá cuối sau phân bổ.',
              ),
              InfoBanner(
                text: online
                    ? 'Đang dùng kết quả kiểm tra availability '
                        'cho giới hạn chọn hiện tại.'
                    : 'Tồn snapshot chỉ là tham khảo, '
                        'không phải hàng đã giữ cho điểm bán.',
              ),
              if (!quote.isComplete)
                InfoBanner(
                  tone: StatusTone.warning,
                  text: 'Chưa có giá hiệu lực cho: '
                      '${quote.missingPriceSkus.join(', ')}. '
                      'Hãy cập nhật snapshot hoặc kiểm tra giá online.',
                ),
              TextField(
                enabled: !_busy,
                decoration: const InputDecoration(
                  hintText: 'Tìm sản phẩm hoặc SKU',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  setState(() => _query = value.trim().toLowerCase());
                },
              ),
              const SizedBox(height: 10),
              if (products.isEmpty)
                const EmptyState(
                  title: 'Không có sản phẩm phù hợp',
                  message: 'Kiểm tra từ khóa hoặc cập nhật snapshot sản phẩm.',
                )
              else
                for (final product in products)
                  _productRow(
                    product,
                    data,
                    retailer,
                    quote,
                    availability?[product.sku],
                  ),
            ],
          ),
        ),
        _bottomBar(data, retailer, online, quote),
      ],
    );
  }

  String _stamp(DateTime? value) {
    if (value == null) {
      return 'chưa đồng bộ';
    }

    return AppDates.timeDay(value.toLocal());
  }

  Widget _productRow(
    Product product,
    CatalogData data,
    Retailer retailer,
    PriceQuote quote,
    ProductAvailability? availability,
  ) {
    final maximum = data.maxQty(product.sku);
    final quantity = _cart[product.sku] ?? 0;
    final price = data.displayPrice(product);
    final pricedLines =
        quote.lines.where((line) => line.sku == product.sku).toList();

    void openDetail() {
      if (_busy) {
        return;
      }

      final promotions = data
          .runningPromotions(retailerCode: retailer.code)
          .where((promotion) =>
              promotion.groupSkus.contains(product.sku) ||
              promotion.rules.any((rule) => rule.sku == product.sku))
          .toList();

      unawaited(Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ProductDetailScreen(
            product: product,
            unitPrice: price,
            availability: availability,
            promotions: promotions,
          ),
        ),
      ));
    }

    return AppCard(
      onTap: _busy ? null : openDetail,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${product.sku} · ${product.name}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: _busy ? null : openDetail,
                tooltip: 'Chi tiết ${product.name}',
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Text(
            price == null
                ? '${product.pack} · Chưa có giá hiệu lực trong snapshot'
                : '${product.pack} · '
                    '${Money.format(price)}/thùng · dự kiến',
            style: TextStyle(
              color: price == null ? AppColors.warning : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          if (availability != null)
            WarehouseStockList(
              warehouses: availability.warehouses,
              onViewAll: _busy ? null : openDetail,
            ),
          Row(
            children: [
              Expanded(
                child: Text(
                  maximum == 0
                      ? (availability == null
                          ? 'Chưa có số lượng có thể chọn từ snapshot'
                          : availability.quantity <= 0
                              ? 'Không có hàng đủ điều kiện để giao'
                              : 'Chưa đủ hàng để đặt theo bội ${OrderLimits.step} thùng')
                      : 'Chọn số lượng · bội ${OrderLimits.step} thùng',
                  style: TextStyle(
                    color:
                        maximum == 0 ? AppColors.warning : AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
              if (maximum > 0)
                QuantityStepper(
                  value: quantity,
                  step: OrderLimits.step,
                  max: maximum,
                  onChanged: (value) {
                    if (_busy) {
                      return;
                    }
                    setState(() => _cart[product.sku] = value);
                  },
                ),
            ],
          ),
          if (pricedLines.isNotEmpty && pricedLines.first.hasDiscount)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${pricedLines.first.promoName.isEmpty ? 'Khuyến mãi' : pricedLines.first.promoName} · '
                'giảm dự kiến '
                '${Money.format(pricedLines.first.discount)}',
                style: const TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bottomBar(
    CatalogData data,
    Retailer retailer,
    bool online,
    PriceQuote quote,
  ) {
    final count = _lines.length;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.divider),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count == 0 ? 'Giỏ hàng trống' : '$count sản phẩm',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                    ),
                  ),
                  Text(
                    quote.isComplete
                        ? Money.format(quote.finalAmount)
                        : 'Chưa đủ dữ liệu giá',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (count > 0 && quote.isComplete)
                    const Text(
                      'Tạm tính trên máy',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  if (quote.isComplete && quote.discount > 0)
                    Text(
                      'Giảm dự kiến ${Money.format(quote.discount)}',
                      style: const TextStyle(
                        color: AppColors.success,
                        fontSize: 12.5,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 160,
              child: FilledButton(
                onPressed: count == 0 || _busy
                    ? null
                    : () => _review(data, retailer, online),
                child: Text(
                  _busy ? 'Đang xử lý...' : 'Xem giỏ & đặt hàng',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Gọi bằng ApiClient hiện có vì RetailerRepository trên nhánh hiện tại
  /// chưa có method orderEligibility.
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

    if (user.role == UserRole.retailer) {
      return;
    }

    if (user.role != UserRole.sales) {
      throw const ApiException(
        kind: ApiErrorKind.forbidden,
        message: 'Tài khoản không được sử dụng luồng đặt hàng Sales.',
      );
    }

    if (retailer.id.isEmpty) {
      throw const ApiException(
        kind: ApiErrorKind.validation,
        message: 'Điểm bán thiếu ID máy chủ. Hãy cập nhật snapshot.',
      );
    }

    final response = await ref.read(apiClientProvider).get(
          '/retailers/${Uri.encodeComponent(retailer.id)}'
          '/order-eligibility',
        );

    if (!mounted || !_isCurrentUser(user.id)) {
      throw const ApiException(
        kind: ApiErrorKind.forbidden,
        message: 'Phiên đăng nhập đã thay đổi.',
      );
    }

    final result = asMap(response);
    final eligible = result['isEligible'];
    final reasons = result['reasons'];

    if (eligible is! bool ||
        reasons is! List ||
        reasons.any((reason) => reason is! String) ||
        asStr(result['salesUserId']) != user.id ||
        asStr(result['retailerId']) != retailer.id) {
      throw const ApiException(
        kind: ApiErrorKind.server,
        message: 'Phản hồi kiểm tra điều kiện đặt hàng không hợp lệ.',
      );
    }

    if (!eligible) {
      final message = reasons.cast<String>().join('\n');

      throw ApiException(
        kind: ApiErrorKind.forbidden,
        message: message.isEmpty
            ? 'Điểm bán hiện chưa đủ điều kiện đặt hàng.'
            : message,
      );
    }
  }

  Future<void> _review(
    CatalogData data,
    Retailer retailer,
    bool online,
  ) async {
    if (_busy || _lines.isEmpty) {
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) {
      return;
    }

    if (!online && user.role == UserRole.retailer) {
      showAppSnack(
        context,
        'Retailer cần kết nối mạng để gửi đơn.',
        error: true,
      );
      return;
    }

    if (!online &&
        user.role == UserRole.sales &&
        !_cachedRetailerIsActive(data, retailer)) {
      showAppSnack(
        context,
        'Điểm bán chưa hoạt động theo snapshot hiện có.',
        error: true,
      );
      return;
    }

    final estimatedAt = AppClock.now();
    final lines = _lines;
    final localEstimate = data.quote(
      lines,
      retailer.code,
      now: estimatedAt,
    );

    var quote = localEstimate;
    var estimated = true;

    setState(() => _busy = true);

    try {
      if (online) {
        await _ensureSalesOrderEligibility(retailer);

        if (!mounted || !_isCurrentUser(user.id)) {
          return;
        }

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
        } on ApiException catch (error) {
          if (!error.isNetwork || !localEstimate.isComplete) {
            rethrow;
          }
          // Chỉ fallback khi mất kết nối và local estimate đầy đủ.
        }
      }

      if (!quote.isComplete) {
        throw ApiException(
          kind: ApiErrorKind.validation,
          message: 'Chưa có giá hiệu lực cho '
              '${quote.missingPriceSkus.join(', ')}. '
              'Hãy cập nhật snapshot hoặc kiểm tra giá online.',
        );
      }

      if (!mounted || !_isCurrentUser(user.id)) {
        return;
      }

      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => OrderConfirmSheet(
          retailer: retailer,
          quote: quote,
          online: online,
          estimated: estimated,
          localEstimate: localEstimate.isComplete ? localEstimate : null,
          snapshotAt: data.lastSyncAt,
          estimatedAt: estimatedAt,
        ),
      );

      if (confirmed != true || !_isCurrentUser(user.id)) {
        return;
      }

      await _submit(
        data,
        retailer,
        localEstimate: localEstimate.isComplete ? localEstimate : null,
        estimatedAt: estimatedAt,
      );
    } catch (error) {
      if (mounted && _isCurrentUser(user.id)) {
        showAppSnack(
          context,
          ApiException.describe(error),
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _submit(
    CatalogData data,
    Retailer retailer, {
    required PriceQuote? localEstimate,
    required DateTime estimatedAt,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      return;
    }

    final repository = ref.read(orderRepositoryProvider);
    final productsBySku = {
      for (final product in data.products) product.sku: product,
    };

    final lines = _lines
        .map(
          (line) => CartLine(
            productId: productsBySku[line.sku]?.id ?? '',
            sku: line.sku,
            qty: line.qty,
          ),
        )
        .toList();

    if (retailer.id.isEmpty ||
        lines.isEmpty ||
        lines.any((line) => line.productId.isEmpty)) {
      showAppSnack(
        context,
        'Retailer hoặc sản phẩm thiếu ID máy chủ. '
        'Hãy cập nhật snapshot.',
        error: true,
      );
      return;
    }

    final online = ref.read(networkMonitorProvider).online;

    if (!online && user.role != UserRole.sales) {
      showAppSnack(
        context,
        'Tài khoản này cần kết nối mạng để gửi đơn.',
        error: true,
      );
      return;
    }

    setState(() => _busy = true);

    try {
      var code = '';
      var message = '';

      Future<void> saveOffline(String notice) async {
        if (!mounted || !_isCurrentUser(user.id)) {
          throw const ApiException(
            kind: ApiErrorKind.forbidden,
            message: 'Phiên đăng nhập đã thay đổi.',
          );
        }

        final estimate = localEstimate;

        if (estimate == null || !estimate.isComplete) {
          throw const ApiException(
            kind: ApiErrorKind.validation,
            message: 'Chưa có bản giá offline đầy đủ để lưu đơn. '
                'Hãy cập nhật snapshot rồi thử lại.',
          );
        }

        final entry = await repository.createOffline(
          retailer: retailer,
          lines: lines,
          estimate: estimate,
          estimatedAt: estimatedAt,
          snapshot: data.snapshot,
        );

        code = entry.localCode;
        message = notice;
      }

      if (online) {
        try {
          await _ensureSalesOrderEligibility(retailer);

          if (!mounted || !_isCurrentUser(user.id)) {
            return;
          }

          // Giữ kiểm tra availability hiện có.
          final quantities = await ref.read(ordersApiProvider).availability(
                retailer.id,
                lines.map((line) => line.productId).toList(),
              );

          if (!mounted || !_isCurrentUser(user.id)) {
            return;
          }

          if (lines.any(
            (line) => line.qty > OrderLimits.maxQty(quantities[line.sku] ?? 0),
          )) {
            ref.invalidate(
              _orderAvailabilityProvider(retailer.id),
            );

            setState(() {
              for (final entry in _cart.entries.toList()) {
                final maximum = OrderLimits.maxQty(
                  quantities[entry.key] ?? 0,
                );

                if (entry.value > maximum) {
                  _cart[entry.key] = maximum;
                }
              }
            });

            showAppSnack(
              context,
              'Số lượng đáp ứng vừa thay đổi. '
              'Hãy kiểm tra lại giỏ hàng.',
              error: true,
            );
            return;
          }

          final order = await repository.createOnline(
            NewOrderRequest(
              clientOrderKey: _clientOrderKey,
              retailerId: retailer.id,
              lines: lines,
              deliveryAddress: retailer.address,
            ),
          );

          code = order.id;
          message = order.status.isRejectedOrCancelled
              ? 'Đơn ${order.code} bị từ chối: ${order.rejectReason}'
              : 'Đã tạo SO ${order.code}. '
                  'Hệ thống đang phân bổ và sẽ gửi báo giá cho Retailer.';
        } on ApiException catch (error) {
          if (!error.isNetwork || user.role != UserRole.sales) {
            rethrow;
          }

          await saveOffline(
            'Mất kết nối — đã lưu đơn và bản tạm tính trên máy. '
            'Đơn sẽ được gửi theo cơ chế đồng bộ hiện tại.',
          );
        }
      } else {
        await saveOffline(
          'Đã lưu đơn và bản tạm tính trên máy.',
        );
      }

      if (!mounted || !_isCurrentUser(user.id)) {
        return;
      }

      ref.read(dataVersionProvider.notifier).state++;

      if (online) {
        unawaited(
          ref.read(syncServiceProvider.notifier).refreshSnapshot(),
        );
      }

      showAppSnack(context, message);

      context.pushReplacement(
        user.role == UserRole.retailer
            ? AppRoutes.rtOrderDetail(code)
            : AppRoutes.salesOrderDetail(code),
      );
    } on ApiException catch (error) {
      if (mounted && _isCurrentUser(user.id)) {
        showAppSnack(
          context,
          error.message,
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}
