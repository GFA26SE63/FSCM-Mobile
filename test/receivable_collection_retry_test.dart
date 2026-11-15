import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/models/receivable.dart';
import 'package:fscm_mobile/data/remote/receivables_api.dart';

class CollectionTransport implements ApiTransport {
  final requests = <ApiRequest>[];
  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    return const ApiResponse(statusCode: 200, data: {
      'orderId': 'order-1',
      'orderCode': 'SO-1',
      'status': 'Paid',
      'amount': 100,
      'outstandingAmount': 0,
      'version': 5
    });
  }
}

void main() {
  test(
      'retry of the same payment snapshot preserves the collection operation key',
      () async {
    final transport = CollectionTransport();
    final client = ApiClient(transport: transport, tokenReader: () => 'access');
    addTearDown(client.dispose);
    final api = ReceivablesApi(client);
    final snapshot = Receivable.fromJson({
      'orderId': 'order-1',
      'orderCode': 'SO-1',
      'status': 'Unpaid',
      'version': 4,
      'amount': 100
    });
    await api.collect(snapshot);
    await api.collect(snapshot);
    expect(transport.requests[0].headers['Idempotency-Key'],
        transport.requests[1].headers['Idempotency-Key']);
    expect(
        transport.requests.first.path, '/receivables/orders/order-1/collect');
    expect((transport.requests.first.body as Map)['expectedVersion'], 4);
    expect((transport.requests.first.body as Map)['collectionMethod'], 'Cash');
  });
  test('a settled snapshot does not send another collection', () async {
    final transport = CollectionTransport();
    final client = ApiClient(transport: transport, tokenReader: () => 'access');
    addTearDown(client.dispose);
    final paid = Receivable.fromJson({'orderId': 'order-1', 'status': 'Paid'});
    expect(await ReceivablesApi(client).collect(paid), same(paid));
    expect(transport.requests, isEmpty);
  });
}
