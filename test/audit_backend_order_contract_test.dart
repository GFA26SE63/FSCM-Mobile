import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/data/models/order.dart';

void main() {
  test('Audit: backend order DTO preserves code and final amount', () {
    final order = Order.fromJson({
      'id': '00000000-0000-0000-0000-000000000001',
      'orderCode': 'DH-000001',
      'status': 'Issued',
      'finalAmount': 800000,
      'paymentMethod': 'Credit',
      'creditTermDays': 14,
      'lines': [
        {'sku': 'SKU001', 'productName': 'Milk', 'quantity': 8, 'unitPrice': 100000}
      ],
      'shipments': [],
      'warehouseProgress': [],
    });
    expect(order.code, 'DH-000001');
    expect(order.total, 800000);
    expect(order.status.canConfirmReceipt, isTrue);
    expect(order.creditTerm, 14);
    expect(order.lines.single.qty, 8);
  });
}
