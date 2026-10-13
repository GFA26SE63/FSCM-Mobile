import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/price_quote.dart';

/// JSON element sent to `POST /orders/sync`. The UUID [clientRequestId] is
/// the idempotency key; [offlineCode] (`OFF-{device}-{0000}`) is the
/// human-readable temporary code. The server re-prices and re-allocates:
/// [localFinal] is only an estimate kept for the comparison screen.
class OfflineOrderPayload {
  const OfflineOrderPayload({
    required this.clientRequestId,
    required this.offlineCode,
    required this.retailerCode,
    required this.retailerName,
    required this.createdAt,
    required this.payment,
    required this.creditTerm,
    required this.lines,
    required this.localTotal,
    required this.localDiscount,
    this.localPromoIds = const <String>[],
  });

  factory OfflineOrderPayload.fromJson(Map<String, dynamic> j) =>
      OfflineOrderPayload(
        clientRequestId: asStr(j['clientRequestId']),
        offlineCode: asStr(j['offlineCode']),
        retailerCode: asStr(j['retailerCode']),
        retailerName: asStr(j['retailerName']),
        createdAt: asDate(j['createdAt']) ?? DateTime.now(),
        payment: PaymentMethod.fromCode(asStrOrNull(j['payment'])),
        creditTerm: asInt(j['creditTerm']),
        lines: mapList(j['lines'], CartLine.fromJson),
        localTotal: asInt(j['localTotal']),
        localDiscount: asInt(j['localDiscount']),
        localPromoIds: asStrList(j['localPromoIds']),
      );

  final String clientRequestId;
  final String offlineCode;
  final String retailerCode;
  final String retailerName;
  final DateTime createdAt;
  final PaymentMethod payment;
  final int creditTerm;
  final List<CartLine> lines;
  final int localTotal;
  final int localDiscount;
  final List<String> localPromoIds;

  int get localFinal => localTotal - localDiscount;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'clientRequestId': clientRequestId,
        'offlineCode': offlineCode,
        'retailerCode': retailerCode,
        'retailerName': retailerName,
        'createdAt': isoOrNull(createdAt),
        'payment': payment.code,
        'creditTerm': creditTerm,
        'lines': lines.map((l) => l.toJson()).toList(),
        'localTotal': localTotal,
        'localDiscount': localDiscount,
        'localPromoIds': localPromoIds,
      };
}

/// Row of the OfflineOrderQueue table.
class OfflineOrder {
  const OfflineOrder({
    required this.clientRequestId,
    required this.payload,
    required this.status,
    required this.createdAt,
    this.id,
    this.retryCount = 0,
    this.error = '',
    this.lastAttemptAt,
    this.syncedAt,
    this.serverOrderCode = '',
    this.syncMode = '',
    this.finalAmount,
    this.promoChanged = false,
    this.changeReason = '',
  });

  /// Auto-increment primary key = creation order (tie-break for equal
  /// timestamps).
  final int? id;
  final String clientRequestId;
  final OfflineOrderPayload payload;
  final SyncStatus status;
  final DateTime createdAt;
  final int retryCount;
  final String error;
  final DateTime? lastAttemptAt;
  final DateTime? syncedAt;
  final String serverOrderCode;
  final String syncMode;
  final int? finalAmount;
  final bool promoChanged;
  final String changeReason;

  String get localCode => payload.offlineCode;

  OfflineOrder copyWith({
    SyncStatus? status,
    int? retryCount,
    String? error,
    DateTime? lastAttemptAt,
    DateTime? syncedAt,
    String? serverOrderCode,
    String? syncMode,
    int? finalAmount,
    bool? promoChanged,
    String? changeReason,
  }) =>
      OfflineOrder(
        id: id,
        clientRequestId: clientRequestId,
        payload: payload,
        status: status ?? this.status,
        createdAt: createdAt,
        retryCount: retryCount ?? this.retryCount,
        error: error ?? this.error,
        lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
        syncedAt: syncedAt ?? this.syncedAt,
        serverOrderCode: serverOrderCode ?? this.serverOrderCode,
        syncMode: syncMode ?? this.syncMode,
        finalAmount: finalAmount ?? this.finalAmount,
        promoChanged: promoChanged ?? this.promoChanged,
        changeReason: changeReason ?? this.changeReason,
      );
}

/// One element of the `POST /orders/sync` response.
class OrderSyncResult {
  const OrderSyncResult({
    required this.clientRequestId,
    required this.accepted,
    this.orderCode = '',
    this.reason = '',
    this.finalAmount,
    this.promoChanged = false,
    this.changeReason = '',
  });

  factory OrderSyncResult.fromJson(Map<String, dynamic> j) => OrderSyncResult(
        clientRequestId: asStr(j['clientRequestId']),
        accepted: asStr(j['status']).toLowerCase() == 'accepted',
        orderCode: asStr(j['orderCode']),
        reason: asStr(j['reason']),
        finalAmount: j['finalAmount'] == null ? null : asInt(j['finalAmount']),
        promoChanged: asBool(j['promoChanged']),
        changeReason: asStr(j['changeReason']),
      );

  final String clientRequestId;
  final bool accepted;
  final String orderCode;
  final String reason;
  final int? finalAmount;
  final bool promoChanged;
  final String changeReason;
}

/// Conversion of a queue row into the order model used by the UI.
Order orderFromOffline(
  OfflineOrder entry, {
  required Map<String, String> productNames,
  required Map<String, int> unitPrices,
  PriceQuote? localQuote,
}) {
  final p = entry.payload;
  final quoteBySku = <String, QuoteLine>{
    for (final l in localQuote?.lines ?? const <QuoteLine>[]) l.sku: l,
  };
  final lines = p.lines.map((l) {
    final q = quoteBySku[l.sku];
    return OrderLine(
      sku: l.sku,
      name: productNames[l.sku] ?? l.sku,
      qty: l.qty,
      unitPrice: unitPrices[l.sku] ?? q?.unitPrice ?? 0,
      discount: q?.discount ?? 0,
      discountPct: q?.pct ?? 0,
      promoId: q?.promoId ?? '',
      promoName: q?.promoName ?? '',
    );
  }).toList();
  final total = lines.fold<int>(0, (s, l) => s + l.base);
  final discount = lines.fold<int>(0, (s, l) => s + l.discount);
  final OrderStatus status = entry.status == SyncStatus.rejected
      ? OrderStatus.rejected
      : OrderStatus.pending;
  return Order(
    code: '',
    offlineCode: p.offlineCode,
    retailerCode: p.retailerCode,
    retailerName: p.retailerName,
    status: status,
    createdAt: p.createdAt,
    lines: lines,
    total: total,
    discount: discount,
    payment: p.payment,
    creditTerm: p.creditTerm,
    rejectReason: entry.status == SyncStatus.rejected ? entry.error : '',
    isOffline: true,
    syncStatus: entry.status,
    syncedAt: entry.syncedAt,
    syncMode: entry.syncMode,
    promoChanged: entry.promoChanged,
    changeReason: entry.changeReason,
    localFinal: p.localFinal,
  );
}
