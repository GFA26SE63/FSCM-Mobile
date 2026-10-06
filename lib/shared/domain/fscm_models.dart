enum SalesOrderStatus {
  pendingSync,
  syncing,
  pendingApproval,
  approved,
  dispatched,
  delivering,
  delivered,
  rejected,
  cancelled,
}

class Product {
  const Product({
    required this.sku,
    required this.name,
    required this.pack,
    required this.category,
    required this.price,
    required this.stock,
  });

  final String sku;
  final String name;
  final String pack;
  final String category;
  final int price;
  final int stock;
}

class Retailer {
  const Retailer({
    required this.id,
    required this.name,
    required this.address,
    required this.area,
    required this.tier,
    required this.points,
    required this.creditTermDays,
  });

  final String id;
  final String name;
  final String address;
  final String area;
  final String tier;
  final int points;
  final int creditTermDays;

  bool get isInSalesArea => area == 'Quận 12';
}

class Promotion {
  const Promotion({
    required this.id,
    required this.name,
    required this.validity,
    required this.description,
  });

  final String id;
  final String name;
  final String validity;
  final String description;
}

class OrderLine {
  const OrderLine({
    required this.product,
    required this.quantity,
    this.discountPercent = 0,
    this.batches = const [],
  });

  final Product product;
  final int quantity;
  final int discountPercent;
  final List<BatchAllocation> batches;

  int get subtotal => product.price * quantity;
  int get discount => (subtotal * discountPercent / 100).round();
  int get total => subtotal - discount;
}

class BatchAllocation {
  const BatchAllocation({
    required this.batchCode,
    required this.quantity,
    required this.expiryDate,
    required this.warehouse,
    this.labelCode,
  });

  final String batchCode;
  final int quantity;
  final String expiryDate;
  final String warehouse;
  final String? labelCode;
}

enum PaymentMethod { cod, cash, bankTransfer, credit }

class PaymentInfo {
  const PaymentInfo({
    this.method = PaymentMethod.cod,
    this.isPaid = false,
    this.paidAmount = 0,
    this.paidAt,
    this.dueDate,
  });

  final PaymentMethod method;
  final bool isPaid;
  final int paidAmount;
  final String? paidAt;
  final String? dueDate;

  PaymentInfo copyWith({bool? isPaid, int? paidAmount, String? paidAt}) {
    return PaymentInfo(
      method: method,
      isPaid: isPaid ?? this.isPaid,
      paidAmount: paidAmount ?? this.paidAmount,
      paidAt: paidAt ?? this.paidAt,
      dueDate: dueDate,
    );
  }
}

class DeliveryInfo {
  const DeliveryInfo({
    required this.vehiclePlate,
    required this.driverName,
    required this.driverPhone,
    required this.departedAt,
  });

  final String vehiclePlate;
  final String driverName;
  final String driverPhone;
  final String departedAt;
}

class SalesOrder {
  const SalesOrder({
    required this.id,
    required this.retailer,
    required this.lines,
    required this.status,
    required this.createdAt,
    this.createdBy = 'Nguyễn Văn An',
    this.wasOffline = false,
    this.syncedAt,
    this.rejectionReason,
    this.payment = const PaymentInfo(),
    this.delivery,
  });

  final String id;
  final Retailer retailer;
  final List<OrderLine> lines;
  final SalesOrderStatus status;
  final String createdAt;
  final String createdBy;
  final bool wasOffline;
  final String? syncedAt;
  final String? rejectionReason;
  final PaymentInfo payment;
  final DeliveryInfo? delivery;

  int get subtotal => lines.fold(0, (sum, line) => sum + line.subtotal);
  int get discount => lines.fold(0, (sum, line) => sum + line.discount);
  int get total => lines.fold(0, (sum, line) => sum + line.total);
  int get totalQuantity => lines.fold(0, (sum, line) => sum + line.quantity);

  SalesOrder copyWith({
    SalesOrderStatus? status,
    String? syncedAt,
    PaymentInfo? payment,
  }) {
    return SalesOrder(
      id: id,
      retailer: retailer,
      lines: lines,
      status: status ?? this.status,
      createdAt: createdAt,
      createdBy: createdBy,
      wasOffline: wasOffline,
      syncedAt: syncedAt ?? this.syncedAt,
      rejectionReason: rejectionReason,
      payment: payment ?? this.payment,
      delivery: delivery,
    );
  }
}

class FscmNotification {
  const FscmNotification({
    required this.id,
    required this.message,
    required this.time,
    this.orderId,
    this.isRead = false,
  });

  final int id;
  final String message;
  final String time;
  final String? orderId;
  final bool isRead;

  FscmNotification markRead() => FscmNotification(
    id: id,
    message: message,
    time: time,
    orderId: orderId,
    isRead: true,
  );
}
