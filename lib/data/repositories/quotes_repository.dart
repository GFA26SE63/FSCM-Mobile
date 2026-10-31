import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fscm_mobile/data/models/sales_order_quote.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/data/remote/quotes_api.dart';

final quotesProvider = FutureProvider.autoDispose<List<SalesOrderQuote>>((ref) async {
  ref.watch(dataVersionProvider);
  final orders = (await ref.watch(ordersProvider.future)).orders.where((o) => o.id.isNotEmpty).toList();
  final api = ref.watch(quotesApiProvider);
  final all = <SalesOrderQuote>[];
  for (final order in orders) { all.addAll(await api.forOrder(order.id)); }
  return all;
});
