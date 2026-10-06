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
  });

  final Product product;
  final int quantity;
  final int discountPercent;

  int get subtotal => product.price * quantity;
  int get discount => (subtotal * discountPercent / 100).round();
  int get total => subtotal - discount;
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

  int get subtotal => lines.fold(0, (sum, line) => sum + line.subtotal);
  int get discount => lines.fold(0, (sum, line) => sum + line.discount);
  int get total => lines.fold(0, (sum, line) => sum + line.total);
  int get totalQuantity => lines.fold(0, (sum, line) => sum + line.quantity);

  SalesOrder copyWith({SalesOrderStatus? status, String? syncedAt}) {
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
    );
  }
}

class SalesNotification {
  const SalesNotification({
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

  SalesNotification markRead() => SalesNotification(
    id: id,
    message: message,
    time: time,
    orderId: orderId,
    isRead: true,
  );
}

enum RetailerLeadStatus { pending, approved, rejected }

class RetailerLead {
  const RetailerLead({
    required this.id,
    required this.name,
    required this.address,
    required this.contact,
    required this.phone,
    required this.status,
    required this.potentialClass,
    this.retailerCode,
    this.reason,
  });

  final String id;
  final String name;
  final String address;
  final String contact;
  final String phone;
  final RetailerLeadStatus status;
  final String potentialClass;
  final String? retailerCode;
  final String? reason;
}
