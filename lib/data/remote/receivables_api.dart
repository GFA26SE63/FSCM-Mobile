import 'package:fscm_mobile/core/config/env.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/receivable.dart';

final receivablesApiProvider = Provider<ReceivablesApi>(
    (ref) => ReceivablesApi(ref.watch(apiClientProvider)));

class ReceivablesApi {
  ReceivablesApi(this._client, {bool useMock = Env.useMock})
      : _useMock = useMock;

  final ApiClient _client;
  final bool _useMock;

  /// Sales: receivables of retailers they look after. Retailer: own debts.
  Future<List<Receivable>> list({String? status}) async {
    final data = await _client.get(
      Endpoints.receivables,
      query: <String, dynamic>{'status': status},
    );
    return unwrapItems(data).map(Receivable.fromJson).toList();
  }

  /// Single full collection (no partial payments, SPEC section 4).
  Future<Receivable> collect(String orderCode) async {
    if (!_useMock) {
      final rows = unwrapItems(await _client.get(Endpoints.receivables));
      final matches =
          rows.where((row) => asStr(row['orderCode']) == orderCode).toList();
      if (matches.length != 1) {
        throw const ApiException(
            kind: ApiErrorKind.notFound,
            message: 'Không tìm thấy khoản phải thu của đơn.');
      }
      final payment = matches.single;
      if (asStr(payment['status']) == 'Paid') {
        return Receivable.fromJson(payment);
      }
      final id = asStr(payment['orderId']);
      final version = asInt(payment['version']);
      final data = await _client.post('/payments/orders/$id/collect', body: {
        'collectionMethod': 'Cash',
        'expectedVersion': version,
        'note': 'Sales xác nhận thu đủ tiền mặt'
      }, headers: {
        'Idempotency-Key': 'cash:$id:$version'
      });
      return Receivable.fromJson(asMap(data));
    }
    final data = await _client.post(Endpoints.receivableCollect(orderCode));
    return Receivable.fromJson(asMap(data));
  }
}
