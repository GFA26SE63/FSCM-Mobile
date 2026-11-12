import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/order.dart';

class OrderPage {
  const OrderPage(
      {required this.items,
      required this.page,
      required this.pageSize,
      required this.totalCount});
  factory OrderPage.fromJson(Map<String, dynamic> json) => OrderPage(
        items: unwrapItems(json).map(Order.fromJson).toList(),
        page: asInt(json['page'], 1),
        pageSize: asInt(json['pageSize'], 20),
        totalCount: asInt(json['totalCount']),
      );
  final List<Order> items;
  final int page;
  final int pageSize;
  final int totalCount;
  bool get hasMore => pageSize > 0 && page * pageSize < totalCount;
}
