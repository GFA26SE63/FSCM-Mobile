import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/price_quote.dart';
import 'package:fscm_mobile/data/models/timeline_entry.dart';

/// Batch allocation of an order line (result of the FEFO allocation engine).
class BatchAllocation {
  const BatchAllocation({
    required this.batchCode,
    required this.qty,
    this.expiry,
    this.warehouseName = '',
    this.labelCode = '',
  });

  factory BatchAllocation.fromJson(Map<String, dynamic> j) => BatchAllocation(
        batchCode: asStr(j['batchCode']),
        qty: asInt(j['qty'] ?? j['quantity'] ?? j['allocatedQuantity']),
        expiry: asDate(j['expiry'] ?? j['batchExpirationDate']),
        warehouseName: asStr(j['warehouseName'] ?? j['warehouseCode']),
        labelCode: asStr(j['labelCode']),
      );

  final String batchCode;
  final int qty;
  final DateTime? expiry;
  final String warehouseName;
  final String labelCode;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'batchCode': batchCode,
        'qty': qty,
        'expiry': isoOrNull(expiry),
        'warehouseName': warehouseName,
        'labelCode': labelCode,
      };
}

class OrderLine {
  const OrderLine({
    required this.sku,
    required this.name,
    required this.qty,
    required this.unitPrice,
    this.discount = 0,
    this.discountPct = 0,
    this.promoId = '',
    this.promoName = '',
    this.batches = const <BatchAllocation>[],
  });

  factory OrderLine.fromJson(Map<String, dynamic> j) => OrderLine(
        sku: asStr(j['sku']),
        name: asStr(j['name'] ?? j['productName']),
        qty: asInt(j['qty'] ?? j['quantity'] ?? j['orderedQuantity']),
        unitPrice: asInt(j['unitPrice']),
        discount: asInt(j['discount'] ?? j['discountAmount']),
        discountPct: asDouble(j['discountPct'] ?? j['discountPercent']),
        promoId: asStr(j['promoId'] ?? j['discountSourceCode']),
        promoName: asStr(j['promoName'] ?? j['discountSourceType']),
        batches: mapList(j['batches'] ?? j['allocations'], BatchAllocation.fromJson),
      );

  final String sku;
  final String name;
  final int qty;
  final int unitPrice;
  final int discount;
  final double discountPct;
  final String promoId;
  final String promoName;
  final List<BatchAllocation> batches;

  int get base => qty * unitPrice;
  int get net => base - discount;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sku': sku,
        'name': name,
        'qty': qty,
        'unitPrice': unitPrice,
        'discount': discount,
        'discountPct': discountPct,
        'promoId': promoId,
        'promoName': promoName,
        'batches': batches.map((b) => b.toJson()).toList(),
      };
}

/// Order as shown to Sales and Retailer. Offline orders that are still in
/// the local queue are mapped to this model too (see `OrderRepository`).
class Order {
  const Order({
    this.id = '',
    required this.code,
    required this.retailerCode,
    required this.retailerName,
    required this.status,
    required this.createdAt,
    required this.lines,
    required this.total,
    required this.discount,
    this.createdByName = '',
    this.payment = PaymentMethod.unselected,
    this.version = 0,
    this.creditTerm = 0,
    this.rejectReason = '',
    this.isOffline = false,
    this.offlineCode = '',
    this.syncStatus,
    this.syncedAt,
    this.syncMode = '',
    this.promoChanged = false,
    this.changeReason = '',
    this.localFinal,
    this.vehiclePlate = '',
    this.driverName = '',
    this.driverPhone = '',
    this.departedAt,
    this.paid = false,
    this.paidAt,
    this.dueDate,
    this.pointsEarned = 0,
    this.pointsPending = false,
    this.labelCodes = const <String>[],
    this.timeline = const <TimelineEntry>[],
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: asStr(j['id']),
        code: asStr(j['code'] ?? j['orderCode']),
        retailerCode: asStr(j['retailerCode']),
        retailerName: asStr(j['retailerName']),
        status: OrderStatus.fromCode(asStrOrNull(j['status'])),
        createdAt: asDate(j['createdAt']) ?? DateTime.now(),
        lines: mapList(j['lines'], OrderLine.fromJson),
        total: asInt(j['total'] ?? j['subtotalAmount'] ?? j['finalAmount']),
        discount: asInt(j['discount'] ?? j['discountAmount']),
        createdByName: asStr(j['createdByName']),
        payment: PaymentMethod.fromCode(asStrOrNull(j['payment'] ?? j['paymentMethod'])),
        creditTerm: asInt(j['creditTerm'] ?? j['creditTermDays']),
        rejectReason: asStr(j['rejectReason'] ?? j['rejectionReason']),
        version: asInt(j['version']),
        isOffline: asBool(j['isOffline']),
        offlineCode: asStr(j['offlineCode']),
        syncedAt: asDate(j['syncedAt']),
        syncMode: asStr(j['syncMode']),
        promoChanged: asBool(j['promoChanged']),
        changeReason: asStr(j['changeReason']),
        localFinal: j['localFinal'] == null ? null : asInt(j['localFinal']),
        vehiclePlate: asStr(j['vehiclePlate']),
        driverName: asStr(j['driverName']),
        driverPhone: asStr(j['driverPhone']),
        departedAt: asDate(j['departedAt']),
        paid: asBool(j['paid']),
        paidAt: asDate(j['paidAt']),
        dueDate: asDate(j['dueDate']),
        pointsEarned: asInt(j['pointsEarned']),
        pointsPending: asBool(j['pointsPending']),
        labelCodes: asStrList(j['labelCodes']),
        timeline: mapList(j['timeline'] ?? j['history'], TimelineEntry.fromJson),
      );

  final String id;
  final String code;
  final String retailerCode;
  final String retailerName;
  final OrderStatus status;
  final DateTime createdAt;
  final List<OrderLine> lines;
  final int total;
  final int discount;
  final String createdByName;
  final PaymentMethod payment;
  final int version;
  final int creditTerm;
  final String rejectReason;

  /// Created while offline (code `OFF-{device}-{0000}` until synced).
  final bool isOffline;
  final String offlineCode;

  /// Only set for orders still in the local queue.
  final SyncStatus? syncStatus;
  final DateTime? syncedAt;
  final String syncMode;

  /// Server re-priced the order differently from the offline estimate.
  final bool promoChanged;
  final String changeReason;
  final int? localFinal;

  // Delivery snapshot (vehicle + driver master data, SPEC section 2).
  final String vehiclePlate;
  final String driverName;
  final String driverPhone;
  final DateTime? departedAt;

  final bool paid;
  final DateTime? paidAt;
  final DateTime? dueDate;
  final int pointsEarned;
  final bool pointsPending;

  /// Labels (TEM) shipped for this order - the retailer scans them.
  final List<String> labelCodes;
  final List<TimelineEntry> timeline;

  int get finalAmount => total - discount;
  bool get hasDelivery => vehiclePlate.isNotEmpty;
  bool get isLocalQueued =>
      syncStatus != null && syncStatus != SyncStatus.synced;

  String get displayCode => code.isNotEmpty ? code : offlineCode;

  String get itemsSummary =>
      lines.map((l) => '${l.name} ×${l.qty}').join(' · ');

  /// Groups line discounts by promotion for the summary card.
  List<AppliedPromo> get appliedPromos {
    final byId = <String, List<OrderLine>>{};
    for (final l in lines) {
      if (l.discount > 0) {
        byId.putIfAbsent(l.promoId, () => <OrderLine>[]).add(l);
      }
    }
    return byId.entries.map((e) {
      final first = e.value.first;
      final amount = e.value.fold<int>(0, (s, l) => s + l.discount);
      final detail = e.value
          .map((l) => '${l.sku} × ${l.qty} (−${_pct(l.discountPct)}%)')
          .join(', ');
      return AppliedPromo(
        id: e.key,
        name: first.promoName,
        typeLabel: '',
        detail: detail,
        amount: amount,
      );
    }).toList();
  }

  static String _pct(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  Order copyWith({
    OrderStatus? status,
    bool? paid,
    DateTime? paidAt,
    int? pointsEarned,
    bool? pointsPending,
    List<TimelineEntry>? timeline,
  }) =>
      Order(
        id: id,
        code: code,
        retailerCode: retailerCode,
        retailerName: retailerName,
        status: status ?? this.status,
        createdAt: createdAt,
        lines: lines,
        total: total,
        discount: discount,
        createdByName: createdByName,
        payment: payment,
        version: version,
        creditTerm: creditTerm,
        rejectReason: rejectReason,
        isOffline: isOffline,
        offlineCode: offlineCode,
        syncStatus: syncStatus,
        syncedAt: syncedAt,
        syncMode: syncMode,
        promoChanged: promoChanged,
        changeReason: changeReason,
        localFinal: localFinal,
        vehiclePlate: vehiclePlate,
        driverName: driverName,
        driverPhone: driverPhone,
        departedAt: departedAt,
        paid: paid ?? this.paid,
        paidAt: paidAt ?? this.paidAt,
        dueDate: dueDate,
        pointsEarned: pointsEarned ?? this.pointsEarned,
        pointsPending: pointsPending ?? this.pointsPending,
        labelCodes: labelCodes,
        timeline: timeline ?? this.timeline,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'code': code,
        'retailerCode': retailerCode,
        'retailerName': retailerName,
        'status': status.code,
        'createdAt': isoOrNull(createdAt),
        'lines': lines.map((l) => l.toJson()).toList(),
        'total': total,
        'discount': discount,
        'createdByName': createdByName,
        'payment': payment.code,
        'version': version,
        'creditTerm': creditTerm,
        'rejectReason': rejectReason,
        'isOffline': isOffline,
        'offlineCode': offlineCode,
        'syncedAt': isoOrNull(syncedAt),
        'syncMode': syncMode,
        'promoChanged': promoChanged,
        'changeReason': changeReason,
        'localFinal': localFinal,
        'vehiclePlate': vehiclePlate,
        'driverName': driverName,
        'driverPhone': driverPhone,
        'departedAt': isoOrNull(departedAt),
        'paid': paid,
        'paidAt': isoOrNull(paidAt),
        'dueDate': isoOrNull(dueDate),
        'pointsEarned': pointsEarned,
        'pointsPending': pointsPending,
        'labelCodes': labelCodes,
        'timeline': timeline.map((t) => t.toJson()).toList(),
      };
}

/// Request body of `POST /orders` (online order creation).
class NewOrderRequest {
  const NewOrderRequest({
    required this.clientOrderKey,
    required this.retailerId,
    required this.lines,
    this.deliveryAddress,
    this.note,
  });

  final String clientOrderKey;
  final String retailerId;
  final List<CartLine> lines;
  final String? deliveryAddress;
  final String? note;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'clientOrderKey': clientOrderKey,
        'retailerId': retailerId,
        'paymentMethod': null,
        'deliveryAddress': deliveryAddress,
        'note': note,
        'lines': lines.map((l) => l.toJson()).toList(),
      };
}

/// SKU + quantity (cartons) in the cart or in a request body.
class CartLine {
  const CartLine({this.productId = '', required this.sku, required this.qty});

  factory CartLine.fromJson(Map<String, dynamic> j) =>
      CartLine(
        productId: asStr(j['productId']),
        sku: asStr(j['sku']),
        qty: asInt(j['qty'] ?? j['quantity']),
      );

  final String productId;
  final String sku;
  final int qty;

  CartLine withQty(int q) => CartLine(productId: productId, sku: sku, qty: q);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'productId': productId,
        'sku': sku,
        'quantity': qty,
        'qty': qty,
      };
}
