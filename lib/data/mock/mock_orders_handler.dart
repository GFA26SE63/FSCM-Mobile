import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/data/mock/mock_http.dart';
import 'package:fscm_mobile/data/mock/mock_store.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/loyalty.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/receivable.dart';
import 'package:fscm_mobile/data/models/retailer.dart';
import 'package:fscm_mobile/data/models/timeline_entry.dart';
import 'package:fscm_mobile/data/pricing/promotion_calculator.dart';

/// `/orders`, `POST /orders/sync`, `POST /orders/{code}/confirm-receipt`.
class MockOrdersHandler extends MockHandler {
  MockOrdersHandler(super.store);

  @override
  ApiResponse? handle(MockRequest r) {
    final user = r.user;
    if (user == null) return null;

    if (r.matches('GET', '/orders')) return _list(user, r);
    if (r.matches('GET', '/allocation-runs/orders/*/result')) {
      return _allocationResult(r.segments[2]);
    }
    if (r.matches('POST', '/orders/sync')) return _sync(user, r);
    if (r.matches('POST', '/orders')) return _create(user, r);
    if (r.matches('GET', '/orders/*')) {
      final o = store.orderByCode(r.segments[1]);
      if (o == null || !_visible(user, o)) {
        return MockReply.notFound('đơn ${r.segments[1]}');
      }
      return MockReply.ok(o.toJson());
    }
    if (r.matches('POST', '/orders/*/cancel')) {
      return _cancel(user, r.segments[1]);
    }
    if (r.matches('POST', '/orders/*/confirm-receipt')) {
      return _confirmReceipt(user, r.segments[1], r.body);
    }
    return null;
  }

  ApiResponse _allocationResult(String orderId) {
    final matches = store.orders.where((o) => o.id == orderId).toList();
    if (matches.isEmpty) {
      return MockReply.notFound('kết quả phân bổ $orderId');
    }
    final order = matches.first;
    final lines = <Map<String, dynamic>>[];
    for (var i = 0; i < order.lines.length; i++) {
      final line = order.lines[i];
      lines.add(<String, dynamic>{
        'salesOrderLineId': 'mock-line-${order.code}-$i',
        'sku': line.sku,
        'lineNumber': i + 1,
        'orderedQuantity': line.qty,
        'allocatedQuantity': line.qty,
        'shortageQuantity': 0,
        'outcome': 'Allocated',
        'reason': '',
        'finalAmount': line.net,
      });
    }
    return MockReply.ok(<String, dynamic>{
      'salesOrderId': order.id,
      'orderCode': order.code,
      'allocationRunId': 'mock-run-01',
      'runCode': 'DOT-MOCK-01',
      'businessDate': '2026-10-27',
      'cutoffAt': '2026-10-27T00:00:00Z',
      'approvedAt': '2026-10-27T00:30:00Z',
      'planVersionNumber': 1,
      'isFulfilled': true,
      'shortageReason': null,
      'hasReservedStock': true,
      'canResubmitKeepingPriority': false,
      'finalAmount': order.finalAmount,
      'lines': lines,
    });
  }

  // ------------------------------------------------------------------ list

  bool _visible(MockUser user, Order o) {
    switch (user.role) {
      case UserRole.sales:
        final retailer = store.retailer(o.retailerCode);
        return retailer != null && retailer.areaCode == user.areaCode;
      case UserRole.retailer:
        return o.retailerCode == user.retailerCode;
      default:
        return true;
    }
  }

  ApiResponse _list(MockUser user, MockRequest r) {
    final status = r.queryStr('status').toLowerCase();
    final search = r.queryStr('search').toLowerCase();
    final list = store.orders.where(_visibleFor(user)).where((o) {
      if (status.isNotEmpty && o.status.code.toLowerCase() != status) {
        return false;
      }
      if (search.isEmpty) return true;
      return o.code.toLowerCase().contains(search) ||
          o.retailerName.toLowerCase().contains(search);
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return MockReply.page(list.map((o) => o.toJson()).toList());
  }

  bool Function(Order) _visibleFor(MockUser user) => (o) => _visible(user, o);

  // ---------------------------------------------------------------- create

  Order _build({
    required String code,
    required Retailer retailer,
    required List<CartLine> lines,
    required MockUser user,
    required PaymentMethod payment,
    required int term,
    required OrderStatus status,
    required DateTime createdAt,
    String reason = '',
    String offlineCode = '',
    int? localFinal,
    bool promoChanged = false,
    String changeReason = '',
    DateTime? syncedAt,
    String syncMode = '',
    List<TimelineEntry> timeline = const <TimelineEntry>[],
  }) {
    final quote = PromotionCalculator.quote(
      lines: lines,
      retailerCode: retailer.code,
      promotions: store.serverPromotions(),
      products: store.productMap,
      prices: store.prices,
      now: store.now(),
    );
    final orderLines = quote.lines.map((l) {
      return OrderLine(
        sku: l.sku,
        name: l.name,
        qty: l.qty,
        unitPrice: l.unitPrice,
        discount: l.discount,
        discountPct: l.pct,
        promoId: l.promoId,
        promoName: l.promoName,
        batches: status == OrderStatus.rejected
            ? const <BatchAllocation>[]
            : <BatchAllocation>[
                BatchAllocation(
                  batchCode: 'WH-TA-${l.sku}-18102026',
                  qty: l.qty,
                  expiry: DateTime(2026, 10, 18),
                  warehouseName: 'Kho Thới An',
                ),
              ],
      );
    }).toList();
    return Order(
      id: 'mock-order-$code',
      code: code,
      retailerCode: retailer.code,
      retailerName: retailer.name,
      status: status,
      createdAt: createdAt,
      lines: orderLines,
      total: quote.total,
      discount: quote.discount,
      createdByName: user.fullName,
      payment: payment,
      creditTerm: payment == PaymentMethod.credit ? term : 0,
      rejectReason: reason,
      isOffline: offlineCode.isNotEmpty,
      offlineCode: offlineCode,
      localFinal: localFinal,
      promoChanged: promoChanged,
      changeReason: changeReason,
      syncedAt: syncedAt,
      syncMode: syncMode,
      timeline: timeline,
    );
  }

  /// null when OK, otherwise the Vietnamese rejection reason.
  String? _check(MockUser user, Retailer retailer, PaymentMethod payment,
      List<CartLine> lines) {
    if (retailer.areaCode != user.areaCode) {
      return 'Điểm bán ${retailer.code} nằm ngoài khu vực ${user.areaName ?? ''} của bạn - không tạo được đơn trái vùng.';
    }
    if (payment == PaymentMethod.credit && !retailer.creditAllowed) {
      return 'Điểm bán ${retailer.code} chưa được phép mua công nợ.';
    }
    final need = <String, int>{};
    for (final l in lines) {
      need[l.sku] = (need[l.sku] ?? 0) + l.qty;
    }
    for (final e in need.entries) {
      final available = store.stock[e.key] ?? 0;
      if (e.value > available) {
        return 'Không đủ hàng khả dụng: ${e.key} cần ${e.value} thùng, chỉ còn $available thùng.';
      }
    }
    return null;
  }

  void _reserve(List<CartLine> lines) {
    for (final l in lines) {
      final left = (store.stock[l.sku] ?? 0) - l.qty;
      store.stock[l.sku] = left < 0 ? 0 : left;
    }
  }

  ApiResponse _create(MockUser user, MockRequest r) {
    final retailer = store.retailer(asStr(r.body['retailerCode']));
    if (retailer == null) return MockReply.notFound('điểm bán');
    final lines = mapList(r.body['lines'], CartLine.fromJson)
        .where((l) => l.qty > 0)
        .toList();
    if (lines.isEmpty) return MockReply.invalid('Đơn hàng chưa có sản phẩm.');
    final payment = PaymentMethod.fromCode(asStrOrNull(r.body['payment']));
    final term = payment == PaymentMethod.credit ? retailer.creditTerm : 0;
    if (retailer.areaCode != user.areaCode) {
      return MockReply.forbidden(_check(user, retailer, payment, lines)!);
    }
    final problem = _check(user, retailer, payment, lines);
    final now = store.now();
    final code = store.newOrderCode();
    final rejected = problem != null;
    if (!rejected) _reserve(lines);
    final order = _build(
      code: code,
      retailer: retailer,
      lines: lines,
      user: user,
      payment: payment,
      term: term,
      status: rejected ? OrderStatus.rejected : OrderStatus.pending,
      createdAt: now,
      reason: problem ?? '',
      timeline: <TimelineEntry>[
        TimelineEntry(time: now, label: 'Tạo đơn (online)'),
        if (rejected)
          TimelineEntry(
              time: now, label: 'Hệ thống tự động từ chối - không đủ hàng')
        else ...<TimelineEntry>[
          TimelineEntry(
              time: now,
              label:
                  'Hệ thống tính khuyến mãi, phân bổ kho và batch, tạm giữ hàng'),
          TimelineEntry(time: now, label: 'Chờ duyệt'),
        ],
      ],
    );
    store.orders.insert(0, order);
    store.notify(
      user,
      rejected
          ? 'Đơn $code bị từ chối: ${order.rejectReason} Đã báo cho ${retailer.name}.'
          : 'Đơn $code đã được phân bổ, đang chờ Admin / Operator duyệt.',
      orderCode: code,
      kind: 'order',
    );
    return MockReply.created(order.toJson());
  }

  ApiResponse _cancel(MockUser user, String code) {
    final o = store.orderByCode(code);
    if (o == null || !_visible(user, o)) return MockReply.notFound('đơn $code');
    if (o.status != OrderStatus.pending) {
      return MockReply.conflict('Chỉ hủy được đơn đang chờ duyệt.');
    }
    for (final l in o.lines) {
      store.stock[l.sku] = (store.stock[l.sku] ?? 0) + l.qty;
    }
    final updated = o.copyWith(
      status: OrderStatus.cancelled,
      timeline: <TimelineEntry>[
        ...o.timeline,
        TimelineEntry(
            time: store.now(), label: 'Sales hủy đơn - giải phóng hàng đã giữ'),
      ],
    );
    store.replaceOrder(updated);
    return MockReply.ok(updated.toJson());
  }

  // ------------------------------------------------------------------ sync

  ApiResponse _sync(MockUser user, MockRequest r) {
    final payloads = mapList(r.body['orders'], OfflineOrderPayload.fromJson);
    _applyConflictScenario(payloads);
    final results = <Map<String, dynamic>>[];
    // Arrival order = array order (the app sends them in creation order).
    for (final p in payloads) {
      final prior = store.processedSync[p.clientRequestId];
      final result = prior ?? _processOffline(user, p);
      store.processedSync[p.clientRequestId] = result;
      results.add(<String, dynamic>{
        'clientRequestId': result.clientRequestId,
        'status': result.accepted ? 'Accepted' : 'Rejected',
        'orderCode': result.orderCode,
        'reason': result.reason,
        'finalAmount': result.finalAmount,
        'promoChanged': result.promoChanged,
        'changeReason': result.changeReason,
      });
    }
    return MockReply.ok(<String, dynamic>{'results': results});
  }

  /// Prototype scenario: DH-000931 of another Sales (Q12-B) reached the
  /// server first and reserved most of SKU001.
  void _applyConflictScenario(List<OfflineOrderPayload> payloads) {
    if (!store.simulateConflict || store.conflictApplied) return;
    final touchesSku1 =
        payloads.any((p) => p.lines.any((l) => l.sku == 'SKU001'));
    if (!touchesSku1) return;
    store.conflictApplied = true;
    final current = store.stock['SKU001'] ?? 0;
    if (current > 15) store.stock['SKU001'] = 15;
  }

  OrderSyncResult _processOffline(MockUser user, OfflineOrderPayload p) {
    final retailer = store.retailer(p.retailerCode);
    final now = store.now();
    final code = store.newOrderCode();
    if (retailer == null) {
      return OrderSyncResult(
        clientRequestId: p.clientRequestId,
        accepted: false,
        orderCode: code,
        reason: 'Không tìm thấy điểm bán ${p.retailerCode}.',
      );
    }
    final problem = _check(user, retailer, p.payment, p.lines);
    final rejectReason = problem == null
        ? ''
        : (problem.startsWith('Không đủ hàng khả dụng')
            ? 'Không đủ hàng - đơn khác đã được xử lý trước (${_detail(problem)}).'
            : problem);
    final rejected = problem != null;
    if (!rejected) _reserve(p.lines);

    final order = _build(
      code: code,
      retailer: retailer,
      lines: p.lines,
      user: user,
      payment: p.payment,
      term: retailer.creditTerm,
      status: rejected ? OrderStatus.rejected : OrderStatus.pending,
      createdAt: p.createdAt,
      reason: rejectReason,
      offlineCode: p.offlineCode,
      localFinal: p.localFinal,
      syncedAt: now,
      syncMode: 'Tự động khi có mạng',
      timeline: <TimelineEntry>[
        TimelineEntry(
            time: p.createdAt,
            label: 'Tạo đơn khi offline - lưu trên máy, khuyến mãi tạm tính'),
        TimelineEntry(time: now, label: 'Đồng bộ lên hệ thống'),
        if (rejected)
          TimelineEntry(
              time: now,
              label: 'Hệ thống tự động từ chối - đã báo bạn và retailer')
        else
          TimelineEntry(
              time: now,
              label:
                  'Hệ thống tính lại khuyến mãi, phân bổ kho và batch - chờ duyệt'),
      ],
    );

    var promoChanged = false;
    var changeReason = '';
    if (!rejected) {
      final serverIds = order.lines
          .map((l) => l.promoId)
          .where((id) => id.isNotEmpty)
          .toSet();
      final lost =
          p.localPromoIds.where((id) => !serverIds.contains(id)).toList();
      promoChanged = order.finalAmount != p.localFinal;
      if (promoChanged) {
        changeReason = lost.isEmpty
            ? 'Hệ thống tính lại khuyến mãi theo dữ liệu mới nhất.'
            : '${lost.join(', ')} đã bị tạm dừng hoặc hết hiệu lực sau lần tải dữ liệu gần nhất.';
      }
    }
    final finalOrder = Order(
      code: order.code,
      retailerCode: order.retailerCode,
      retailerName: order.retailerName,
      status: order.status,
      createdAt: order.createdAt,
      lines: order.lines,
      total: order.total,
      discount: order.discount,
      createdByName: order.createdByName,
      payment: order.payment,
      creditTerm: order.creditTerm,
      rejectReason: order.rejectReason,
      isOffline: true,
      offlineCode: order.offlineCode,
      syncedAt: order.syncedAt,
      syncMode: order.syncMode,
      promoChanged: promoChanged,
      changeReason: changeReason,
      localFinal: p.localFinal,
      timeline: order.timeline,
    );
    store.orders.insert(0, finalOrder);
    if (rejected) {
      store.notify(
          user, 'Đơn ${p.offlineCode} bị từ chối sau đồng bộ: $rejectReason',
          orderCode: code, kind: 'order');
    }
    return OrderSyncResult(
      clientRequestId: p.clientRequestId,
      accepted: !rejected,
      orderCode: code,
      reason: rejectReason,
      finalAmount: finalOrder.finalAmount,
      promoChanged: promoChanged,
      changeReason: changeReason,
    );
  }

  /// `Không đủ hàng khả dụng: SKU001 cần 60 thùng, chỉ còn 15 thùng.` ->
  /// `SKU001 cần 60 thùng, chỉ còn 15 thùng`.
  String _detail(String problem) {
    final text = problem.substring(problem.indexOf(':') + 1).trim();
    return text.endsWith('.') ? text.substring(0, text.length - 1) : text;
  }

  // -------------------------------------------------------- confirm receipt

  ApiResponse _confirmReceipt(
      MockUser user, String code, Map<String, dynamic> body) {
    final o = store.orderByCode(code);
    if (o == null ||
        user.role != UserRole.retailer ||
        o.retailerCode != user.retailerCode) {
      return MockReply.forbidden('Tem không thuộc đơn của bạn.');
    }
    if (!o.status.canConfirmReceipt) {
      return MockReply.conflict(
          'Đơn ${o.code} chưa ở trạng thái giao hàng nên chưa xác nhận được.');
    }
    final scanned = asStrList(body['labelCodes']).toSet();
    if (scanned.isEmpty && asStr(body['qrToken']).isNotEmpty) {
      scanned.add(asStr(body['qrToken']));
    }
    final foreign = scanned.where((c) => !o.labelCodes.contains(c)).toList();
    if (foreign.isNotEmpty) {
      return MockReply.conflict(
          'Tem ${foreign.first} không thuộc đơn ${o.code}.');
    }
    final missing = o.labelCodes.where((c) => !scanned.contains(c)).toList();
    if (missing.isNotEmpty) {
      return MockReply.conflict(
          'Chưa quét đủ tem: còn thiếu ${missing.join(', ')}.');
    }

    final now = store.now();
    final isCredit = o.payment == PaymentMethod.credit;
    final points = o.finalAmount ~/ 100000;
    final isCod = o.payment == PaymentMethod.cod;
    final due = isCredit
        ? DateTime(now.year, now.month, now.day)
            .add(Duration(days: o.creditTerm))
        : null;

    final updated = Order(
      code: o.code,
      retailerCode: o.retailerCode,
      retailerName: o.retailerName,
      status: OrderStatus.delivered,
      createdAt: o.createdAt,
      lines: o.lines,
      total: o.total,
      discount: o.discount,
      createdByName: o.createdByName,
      payment: o.payment,
      creditTerm: o.creditTerm,
      vehiclePlate: o.vehiclePlate,
      driverName: o.driverName,
      driverPhone: o.driverPhone,
      departedAt: o.departedAt,
      paid: !isCredit && (isCod || o.paid),
      paidAt: !isCredit ? now : null,
      dueDate: due,
      pointsEarned: isCredit ? 0 : points,
      pointsPending: isCredit,
      labelCodes: o.labelCodes,
      timeline: <TimelineEntry>[
        ...o.timeline,
        TimelineEntry(
          time: now,
          label: isCredit
              ? 'Đã quét QR xác nhận nhận hàng - ghi nợ, hạn trả ${AppDates.date(due)}'
              : 'Đã quét QR xác nhận nhận hàng${isCod ? ', thanh toán COD' : ''}',
        ),
      ],
    );
    store.replaceOrder(updated);

    for (final c in o.labelCodes) {
      final l = store.labels[c];
      if (l != null) {
        store.labels[c] = l.copyWith(status: LabelStatus.delivered);
      }
    }

    final loyalty = store.loyalty
        .putIfAbsent(o.retailerCode, () => MockLoyalty(balance: 0));
    final idx = loyalty.ledger.indexWhere(
        (e) => e.orderCode == o.code && e.kind == PointKind.pending);
    final entry = PointLedgerEntry(
      date: now,
      description: isCredit
          ? '${o.code} · công nợ - cộng khi đã thanh toán'
          : '${o.code} · quét QR nhận hàng',
      points: points,
      kind: isCredit ? PointKind.pending : PointKind.earned,
      orderCode: o.code,
    );
    if (idx >= 0) {
      loyalty.ledger[idx] = entry;
    } else {
      loyalty.ledger.insert(0, entry);
    }
    if (!isCredit) loyalty.balance += points;

    if (isCredit && due != null) {
      store.receivables.insert(
        0,
        Receivable(
          orderCode: o.code,
          retailerCode: o.retailerCode,
          retailerName: o.retailerName,
          amount: o.finalAmount,
          status: ReceivableStatus.unpaid,
          deliveredAt: now,
          dueDate: due,
          term: o.creditTerm,
        ),
      );
    }
    for (final u in store.users.where((u) => u.role == UserRole.sales)) {
      store.notify(u,
          'Đơn ${o.code} (${o.retailerName}) đã được retailer xác nhận nhận hàng.',
          orderCode: o.code, kind: 'order');
    }
    return MockReply.ok(<String, dynamic>{
      'order': updated.toJson(),
      'pointsEarned': isCredit ? 0 : points,
      'pointsPending': isCredit,
    });
  }
}
