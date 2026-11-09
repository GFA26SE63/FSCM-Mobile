import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/sales_order_quote.dart';

final quotesApiProvider =
    Provider<QuotesApi>((ref) => QuotesApi(ref.watch(apiClientProvider)));

final orderQuotesProvider = FutureProvider.autoDispose
    .family<List<SalesOrderQuote>, String>((ref, orderId) {
  if (orderId.isEmpty) return Future.value(const <SalesOrderQuote>[]);
  return ref.watch(quotesApiProvider).forOrder(orderId);
});

class QuotesApi {
  QuotesApi(this._client);

  final ApiClient _client;

  Future<List<SalesOrderQuote>> forOrder(String orderId) async {
    final data = await _client.get(Endpoints.quotesForOrder(orderId));
    return asMapList(data).map(SalesOrderQuote.fromJson).toList();
  }

  Future<SalesOrderQuote> accept(
      SalesOrderQuote quote, PaymentMethod paymentMethod) async {
    final data = await _client.post(
      Endpoints.quoteAccept(quote.id),
      body: <String, dynamic>{
        'expectedVersion': quote.version,
        'paymentMethod': paymentMethod.code,
      },
    );
    return SalesOrderQuote.fromJson(asMap(data));
  }

  Future<SalesOrderQuote> reject(SalesOrderQuote quote, String reason) async {
    final data = await _client.post(
      Endpoints.quoteReject(quote.id),
      body: <String, dynamic>{
        'expectedVersion': quote.version,
        'reason': reason,
      },
    );
    return SalesOrderQuote.fromJson(asMap(data));
  }

  Future<void> switchToCredit(String orderId) async {
    final payment = asMap(await _client.get(Endpoints.paymentForOrder(orderId)));
    await _client.post('/payments/orders/$orderId/switch-to-credit',
        body: {'expectedVersion': asInt(payment['version'])});
  }

  Future<PayOsCheckout> createPayOsCheckout(String orderId) async {
    final paymentData = asMap(await _client.get(Endpoints.paymentForOrder(orderId)));
    final data = await _client.post(
      Endpoints.payOsCheckout(orderId),
      body: <String, dynamic>{'expectedVersion': asInt(paymentData['version'])},
    );
    return PayOsCheckout.fromJson(asMap(data));
  }
}
