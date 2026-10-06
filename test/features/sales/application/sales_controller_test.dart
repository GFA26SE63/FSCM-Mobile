import 'package:flutter_test/flutter_test.dart';
import 'package:fmcg/features/sales/application/sales_controller.dart';
import 'package:fmcg/features/sales/domain/sales_models.dart';

void main() {
  group('SalesController', () {
    test('creates an offline order and synchronizes it when online', () async {
      final controller = SalesController();
      final product = controller.products.first;

      controller.selectRetailer(controller.retailers.first);
      controller.changeQuantity(product, 50);
      controller.toggleConnectivity();

      final order = controller.submitOrder();

      expect(order.status, SalesOrderStatus.pendingSync);
      expect(order.wasOffline, isTrue);
      expect(order.lines.single.discountPercent, 5);
      expect(controller.pendingSyncCount, 1);

      controller.toggleConnectivity();
      await controller.syncPendingOrders();

      expect(controller.pendingSyncCount, 0);
      expect(controller.orders.first.status, SalesOrderStatus.pendingApproval);
      expect(controller.orders.first.syncedAt, isNotNull);
    });

    test('enforces the inventory buffer and case quantity', () {
      final controller = SalesController();
      final product = controller.products.first;

      controller.changeQuantity(product, 1000);

      expect(controller.quantityFor(product), 200);
      expect(controller.maxQuantityFor(product), 200);
    });
  });
}
