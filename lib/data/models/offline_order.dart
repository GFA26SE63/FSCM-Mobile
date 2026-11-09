import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/price_quote.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/data/models/offline_expected_condition.dart';
import 'package:fscm_mobile/data/models/offline_condition_conflict.dart';

/// JSON element sent to `POST /orders/sync`. The UUID [clientRequestId] is
/// the idempotency key; [offlineCode] (`OFF-{device}-{0000}`) is the
/// human-readable temporary code. The server re-prices and re-allocates:
/// [localFinal] is only an estimate kept for the comparison screen.
class OfflineOrderPayload {
  const OfflineOrderPayload({
    required this.clientRequestId,
    required this.offlineCode,
    this.retailerId = '',
    required this.retailerCode,
    required this.retailerName,
    required this.createdAt,
    this.payment = PaymentMethod.unselected,
    this.creditTerm = 0,
    required this.lines,
    required this.localTotal,
    required this.localDiscount,
    this.localPromoIds = const <String>[],
    this.localQuote,
    this.estimatedAt,
    this.snapshotVersion,
    this.expectedConditions = const <OfflineExpectedCondition>[],
  });

  factory OfflineOrderPayload.fromJson(Map<String, dynamic> json) {
    final rawQuote = json['localQuote'];

    return OfflineOrderPayload(
      clientRequestId: asStr(
        json['clientRequestId'] ?? json['clientOrderKey'],
      ),
      offlineCode: asStr(json['offlineCode']),
      retailerId: asStr(json['retailerId']),
      retailerCode: asStr(json['retailerCode']),
      retailerName: asStr(json['retailerName']),
      createdAt: asDate(json['createdAt']) ?? DateTime.now(),
      payment: PaymentMethod.fromCode(asStrOrNull(json['payment'])),
      creditTerm: asInt(json['creditTerm']),
      lines: mapList(json['lines'], CartLine.fromJson),
      localTotal: asInt(
        json['localTotal'] ?? json['offlineEstimatedAmount'],
      ),
      localDiscount: asInt(json['localDiscount']),
      localPromoIds: asStrList(json['localPromoIds']),
      localQuote: rawQuote is Map ? PriceQuote.fromJson(asMap(rawQuote)) : null,
      estimatedAt: asDate(json['estimatedAt']),
      snapshotVersion: asStrOrNull(json['snapshotVersion']),
      expectedConditions: mapList(
        json['expectedConditions'],
        OfflineExpectedCondition.fromJson,
      ),
    );
  }

  final String clientRequestId;
  final String offlineCode;
  final String retailerId;
  final String retailerCode;
  final String retailerName;
  final DateTime createdAt;
  final PaymentMethod payment;
  final int creditTerm;
  final List<CartLine> lines;
  final int localTotal;
  final int localDiscount;
  final List<String> localPromoIds;
  final PriceQuote? localQuote;
  final DateTime? estimatedAt;
  final String? snapshotVersion;
  final List<OfflineExpectedCondition> expectedConditions;

  int get localFinal => localTotal - localDiscount;

  bool get hasCompleteExpectedConditions {
    final productIds = lines.map((line) => line.productId).toSet();
    final conditionIds =
        expectedConditions.map((condition) => condition.productId).toSet();

    return productIds.isNotEmpty &&
        !productIds.contains('') &&
        expectedConditions.length == productIds.length &&
        conditionIds.length == expectedConditions.length &&
        conditionIds.containsAll(productIds) &&
        expectedConditions.every((condition) => condition.isValid);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'clientRequestId': clientRequestId,
        'offlineCode': offlineCode,
        'retailerId': retailerId,
        'retailerCode': retailerCode,
        'retailerName': retailerName,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'payment': payment.code,
        'creditTerm': creditTerm,
        'lines': lines.map((line) => line.toJson()).toList(),
        'localTotal': localTotal,
        'localDiscount': localDiscount,
        'localPromoIds': localPromoIds,
        'localQuote': localQuote?.toJson(),
        'estimatedAt': estimatedAt?.toUtc().toIso8601String(),
        'snapshotVersion': snapshotVersion,
        'expectedConditions':
            expectedConditions.map((item) => item.toJson()).toList(),
      };

  Map<String, dynamic> toRequestJson({bool confirmConditionChanges = false}) {
    if (!hasCompleteExpectedConditions) {
      throw const ApiException(
        kind: ApiErrorKind.validation,
        message: 'Draft thiếu điều kiện giá/MLOR gốc. '
            'Không thể gửi bằng dữ liệu điều kiện mới thay thế.',
      );
    }

    return <String, dynamic>{
      'clientOrderKey': clientRequestId,
      'retailerId': retailerId,
      'paymentMethod': null,
      'offlineEstimatedAmount': localFinal,
      if (snapshotVersion != null) 'snapshotVersion': snapshotVersion,
      // Commercial changes require a separate explicit confirmation flow.
      'confirmConditionChanges': confirmConditionChanges,
      'expectedConditions':
          expectedConditions.map((item) => item.toJson()).toList(),
      'lines': lines
          .map(
            (line) => {
              'productId': line.productId,
              'quantity': line.qty,
            },
          )
          .toList(),
    };
  }
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
    this.conditionConflict,
    this.conditionsConfirmed = false,
    this.serverOrder,
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
  final OfflineConditionConflict? conditionConflict;

  /// Persisted only after Sales explicitly accepts the displayed conditions.
  final bool conditionsConfirmed;

  /// Server receipt captured at submission, usable while the device is offline.
  final Order? serverOrder;

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
    OfflineConditionConflict? conditionConflict,
    bool clearConditionConflict = false,
    bool? conditionsConfirmed,
    Order? serverOrder,
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
        conditionConflict: clearConditionConflict
            ? null
            : conditionConflict ?? this.conditionConflict,
        conditionsConfirmed: conditionsConfirmed ?? this.conditionsConfirmed,
        serverOrder: serverOrder ?? this.serverOrder,
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
    this.serverOrder,
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
  final Order? serverOrder;
}

/// Conversion of a queue row into the order model used by the UI.
Order orderFromOffline(OfflineOrder entry) {
  final payload = entry.payload;
  if (entry.status == SyncStatus.synced && entry.serverOrder != null) {
    return Order.fromJson({
      ...entry.serverOrder!.toJson(),
      'isOffline': true,
      'offlineCode': payload.offlineCode,
      'syncStatus': SyncStatus.synced.code,
      'syncedAt': entry.syncedAt?.toUtc().toIso8601String(),
      'syncMode': entry.syncMode,
      'localFinal': payload.localFinal,
      'promoChanged': entry.promoChanged,
      'changeReason': entry.changeReason,
    });
  }
  final quote = payload.localQuote;

  final lines = quote == null
      ? <OrderLine>[]
      : quote.lines
          .map(
            (line) => OrderLine(
              sku: line.sku,
              name: line.name,
              qty: line.qty,
              unitPrice: line.unitPrice,
              grossAmount: line.base,
              discount: line.discount,
              discountPct: line.pct,
              promoId: line.promoId,
              promoName: line.promoName,
            ),
          )
          .toList();

  return Order(
    code: entry.status == SyncStatus.synced ? entry.serverOrderCode : '',
    offlineCode: payload.offlineCode,
    retailerCode: payload.retailerCode,
    retailerName: payload.retailerName,
    status: entry.status == SyncStatus.rejected
        ? OrderStatus.rejected
        : OrderStatus.allocating,
    createdAt: payload.createdAt,
    lines: lines,
    total: payload.localTotal,
    discount: payload.localDiscount,
    payment: PaymentMethod.unselected,
    creditTerm: payload.creditTerm,
    rejectReason: entry.status == SyncStatus.rejected ? entry.error : '',
    isOffline: true,
    syncStatus: entry.status,
    syncedAt: entry.syncedAt,
    syncMode: entry.syncMode,
    promoChanged: entry.promoChanged,
    changeReason: entry.changeReason,
    localFinal: payload.localFinal,
  );
}
