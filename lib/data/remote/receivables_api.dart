import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/receivable.dart';
import 'package:uuid/uuid.dart';

final receivablesApiProvider = Provider<ReceivablesApi>(
    (ref) => ReceivablesApi(ref.watch(apiClientProvider)));

class ReceivablesApi {
  ReceivablesApi(this._client);

  final ApiClient _client;

  /// Sales: receivables of retailers they look after. Retailer: own debts.
  Future<List<Receivable>> list({String? status}) async {
    final data = await _client.get(
      Endpoints.receivables,
      query: <String, dynamic>{'status': status},
    );
    return unwrapItems(data).map(Receivable.fromJson).toList();
  }

  /// Single full collection (no partial payments, SPEC section 4).
  Future<Receivable> collect(Receivable receivable) async {
    final data = await _client.post(
      Endpoints.receivableCollect(receivable.orderId),
      body: <String, dynamic>{
        'collectionMethod': 'Cash',
        'expectedVersion': receivable.version,
        'note': 'Sales confirmed full cash collection on mobile.',
      },
      headers: <String, String>{'Idempotency-Key': const Uuid().v4()},
    );
    return Receivable.fromJson(asMap(data));
  }
}
