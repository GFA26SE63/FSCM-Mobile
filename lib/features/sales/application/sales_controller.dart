import 'package:flutter/foundation.dart';
import 'package:fmcg/features/sales/data/demo_sales_data.dart';
import 'package:fmcg/features/sales/domain/sales_models.dart';
import 'package:fmcg/shared/domain/fscm_models.dart';

class SalesController extends ChangeNotifier {
  bool isAuthenticated = false;
  bool isOnline = true;
  bool isSyncing = false;
  int currentTab = 0;
  int _nextOrderNumber = 1031;

  String lastSync = '07:45 27/09';
  Retailer? selectedRetailer;
  SalesOrder? lastCreatedOrder;

  final List<Product> products = DemoSalesData.products;
  final List<Retailer> retailers = DemoSalesData.retailers;
  final List<Promotion> promotions = DemoSalesData.promotions;
  final List<SalesOrder> orders = DemoSalesData.orders().toList();
  final List<FscmNotification> notifications = DemoSalesData.notifications()
      .toList();
  final List<RetailerLead> leads = DemoSalesData.leads().toList();
  final Map<String, int> _cart = {};

  int get unreadNotificationCount =>
      notifications.where((item) => !item.isRead).length;
  int get pendingSyncCount => orders
      .where((order) => order.status == SalesOrderStatus.pendingSync)
      .length;
  int get cartQuantity =>
      _cart.values.fold(0, (sum, quantity) => sum + quantity);
  bool get hasCart => _cart.isNotEmpty;

  List<OrderLine> get cartLines => _cart.entries.map((entry) {
    final product = products.firstWhere((item) => item.sku == entry.key);
    return OrderLine(
      product: product,
      quantity: entry.value,
      discountPercent: _discountFor(product.sku, entry.value),
    );
  }).toList();

  int get cartSubtotal => cartLines.fold(0, (sum, line) => sum + line.subtotal);
  int get cartDiscount => cartLines.fold(0, (sum, line) => sum + line.discount);
  int get cartTotal => cartSubtotal - cartDiscount;

  void login() {
    isAuthenticated = true;
    notifyListeners();
  }

  void logout() {
    isAuthenticated = false;
    currentTab = 0;
    notifyListeners();
  }

  void setTab(int index) {
    currentTab = index;
    notifyListeners();
  }

  void toggleConnectivity() {
    isOnline = !isOnline;
    notifyListeners();
  }

  void selectRetailer(Retailer retailer) {
    if (selectedRetailer?.id != retailer.id) {
      _cart.clear();
    }
    selectedRetailer = retailer;
    notifyListeners();
  }

  int quantityFor(Product product) => _cart[product.sku] ?? 0;

  int maxQuantityFor(Product product) {
    const inventoryBuffer = 20;
    return ((product.stock - inventoryBuffer) / 10).floor().clamp(0, 9999) * 10;
  }

  void changeQuantity(Product product, int delta) {
    final next = (quantityFor(product) + delta).clamp(
      0,
      maxQuantityFor(product),
    );
    if (next == 0) {
      _cart.remove(product.sku);
    } else {
      _cart[product.sku] = next;
    }
    notifyListeners();
  }

  void removeFromCart(Product product) {
    _cart.remove(product.sku);
    notifyListeners();
  }

  SalesOrder submitOrder() {
    final retailer = selectedRetailer;
    if (retailer == null || _cart.isEmpty) {
      throw StateError('A retailer and at least one product are required.');
    }

    final order = SalesOrder(
      id: 'DH-${_nextOrderNumber++}',
      retailer: retailer,
      lines: List.unmodifiable(cartLines),
      status: isOnline
          ? SalesOrderStatus.pendingApproval
          : SalesOrderStatus.pendingSync,
      createdAt: '10:42 27/09',
      wasOffline: !isOnline,
    );

    orders.insert(0, order);
    lastCreatedOrder = order;
    notifications.insert(
      0,
      FscmNotification(
        id: DateTime.now().microsecondsSinceEpoch,
        message: isOnline
            ? 'Đơn ${order.id} đã gửi và đang chờ duyệt.'
            : 'Đơn ${order.id} đã lưu trên máy và đang chờ đồng bộ.',
        time: '10:42 27/09',
        orderId: order.id,
      ),
    );
    _cart.clear();
    notifyListeners();
    return order;
  }

  Future<void> syncPendingOrders() async {
    if (!isOnline || isSyncing || pendingSyncCount == 0) return;

    isSyncing = true;
    for (var index = 0; index < orders.length; index++) {
      if (orders[index].status == SalesOrderStatus.pendingSync) {
        orders[index] = orders[index].copyWith(
          status: SalesOrderStatus.syncing,
        );
      }
    }
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 700));

    for (var index = 0; index < orders.length; index++) {
      if (orders[index].status == SalesOrderStatus.syncing) {
        orders[index] = orders[index].copyWith(
          status: SalesOrderStatus.pendingApproval,
          syncedAt: '10:45 27/09',
        );
      }
    }
    lastSync = '10:45 27/09';
    isSyncing = false;
    notifyListeners();
  }

  void markNotificationRead(int id) {
    final index = notifications.indexWhere((item) => item.id == id);
    if (index < 0) return;
    notifications[index] = notifications[index].markRead();
    notifyListeners();
  }

  void addRetailerLead({
    required String name,
    required String address,
    required String contact,
    required String phone,
    required String potentialClass,
  }) {
    leads.insert(
      0,
      RetailerLead(
        id: 'KB-${(leads.length + 13).toString().padLeft(4, '0')}',
        name: name,
        address: address,
        contact: contact,
        phone: phone,
        status: RetailerLeadStatus.pending,
        potentialClass: potentialClass,
      ),
    );
    notifyListeners();
  }

  SalesOrder? orderById(String? id) {
    if (id == null) return null;
    for (final order in orders) {
      if (order.id == id) return order;
    }
    return null;
  }

  int _discountFor(String sku, int quantity) {
    if (sku == 'SKU001' && quantity >= 50) return 5;
    if (sku == 'SKU002' && quantity >= 30) return 4;
    if ((sku == 'SKU005' || sku == 'SKU006') && quantity >= 20) return 8;
    if (sku == 'SKU003' || sku == 'SKU004') {
      final comboQuantity = (_cart['SKU003'] ?? 0) + (_cart['SKU004'] ?? 0);
      if (comboQuantity >= 40) return 3;
    }
    return 0;
  }
}
