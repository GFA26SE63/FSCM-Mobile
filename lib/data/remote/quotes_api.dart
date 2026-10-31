import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/sales_order_quote.dart';

final quotesApiProvider = Provider<QuotesApi>((ref) => QuotesApi(ref.watch(apiClientProvider)));

class QuotesApi {
  QuotesApi(this._client);
  final ApiClient _client;
  Future<List<SalesOrderQuote>> forOrder(String orderId) async => mapList(await _client.get(Endpoints.quotesForOrder(orderId)), SalesOrderQuote.fromJson);
  Future<SalesOrderQuote> accept(SalesOrderQuote q) async => SalesOrderQuote.fromJson(asMap(await _client.post(Endpoints.quoteAccept(q.id), body: <String, dynamic>{'expectedVersion': q.version})));
  Future<SalesOrderQuote> reject(SalesOrderQuote q, String reason) async => SalesOrderQuote.fromJson(asMap(await _client.post(Endpoints.quoteReject(q.id), body: <String, dynamic>{'expectedVersion': q.version, 'reason': reason})));
}
