import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/retailer.dart';
import 'package:fscm_mobile/data/models/sales_order_quote.dart';

Order retailerOrderFixture() => Order.fromJson({
      'id': 'order-1',
      'orderCode': 'DH-001',
      'retailerId': 'retailer-1',
      'retailerCode': 'RT001',
      'retailerName': 'Cửa hàng',
      'status': 'Quoted',
      'finalAmount': 1000,
    });

SalesOrderQuote retailerQuoteFixture(
        {String status = 'Issued',
        int revision = 1,
        DateTime? expiresAt,
        String orderId = 'order-1'}) =>
    SalesOrderQuote.fromJson({
      'id': 'quote-$revision',
      'salesOrderId': orderId,
      'orderCode': 'DH-001',
      'status': status,
      'totalAmount': 1000.25,
      'revisionNumber': revision,
      'expiresAt': (expiresAt ?? DateTime.now().add(const Duration(hours: 2)))
          .toUtc()
          .toIso8601String(),
      'version': 3,
    });

Retailer creditRetailerFixture(int days) => Retailer.fromJson({
      'id': 'retailer-1',
      'code': 'RT001',
      'status': 'Active',
      'creditTermDays': days,
    });
