import 'package:fscm_mobile/data/models/json_utils.dart';

class DebtCheckoutAllocation {
  const DebtCheckoutAllocation({
    required this.paymentId,
    required this.orderId,
    required this.orderCode,
    required this.amount,
  });

  factory DebtCheckoutAllocation.fromJson(Map<String, dynamic> json) =>
      DebtCheckoutAllocation(
        paymentId: asStr(json['paymentId']),
        orderId: asStr(json['orderId']),
        orderCode: asStr(json['orderCode']),
        amount: asInt(json['amount']),
      );

  final String paymentId;
  final String orderId;
  final String orderCode;
  final int amount;
}

class DebtCheckout {
  const DebtCheckout({
    required this.id,
    required this.status,
    required this.amount,
    required this.checkoutUrl,
    required this.allocations,
  });

  factory DebtCheckout.fromJson(Map<String, dynamic> json) => DebtCheckout(
        id: asStr(json['id']),
        status: asStr(json['status']),
        amount: asInt(json['amount']),
        checkoutUrl: asStr(json['checkoutUrl']),
        allocations: asMapList(json['allocations'])
            .map(DebtCheckoutAllocation.fromJson)
            .toList(),
      );

  final String id;
  final String status;
  final int amount;
  final String checkoutUrl;
  final List<DebtCheckoutAllocation> allocations;

  bool get isTerminal =>
      status == 'Paid' || status == 'Failed' || status == 'Expired';
}
