import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:fscm_mobile/core/config/device_identity.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/local/app_database.dart';
import 'package:fscm_mobile/data/local/daos/offline_order_dao.dart';
import 'package:fscm_mobile/data/local/daos/sync_state_dao.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/price_quote.dart';
import 'package:fscm_mobile/data/models/retailer.dart';
import 'package:fscm_mobile/data/remote/orders_api.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/sync/sync_queue_logic.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'a committed online order with a lost response survives SQLite and replays once',
      () async {
    SharedPreferences.setMockInitialValues({'device_code': 'TEST'});
    final databaseName =
        'online_recovery_${DateTime.now().microsecondsSinceEpoch}.db';
    final database = AppDatabase(databaseName: databaseName);
    final queue = OfflineOrderDao(database);
    final transport = _LostResponseTransport();
    final client = ApiClient(transport: transport, tokenReader: () => 'token');
    final api = OrdersApi(client);
    addTearDown(() async {
      client.dispose();
      await database.close();
      await deleteDatabase(p.join(await getDatabasesPath(), databaseName));
    });
    final retailer = Retailer.fromJson({
      'id': 'retailer-id',
      'code': 'RT001',
      'name': 'Test',
      'address': 'Original address'
    });
    const request = NewOrderRequest(
      clientOrderKey: '11111111-1111-4111-8111-111111111111',
      retailerId: 'retailer-id',
      lines: [CartLine(productId: 'product-id', sku: 'SKU001', qty: 10)],
      deliveryAddress: 'Original address',
      note: 'Original note',
    );
    await expectLater(api.create(request), throwsA(isA<ApiException>()));
    final repository = OrderRepository(
      api: api,
      queue: queue,
      syncState: SyncStateDao(database),
      device: DeviceIdentity(await SharedPreferences.getInstance()),
      ownerId: 'sales',
      isSales: true,
      isCurrentUser: () => true,
    );
    final draft = await repository.createOffline(
      orderStep: 1,
      retailer: retailer,
      lines: request.lines,
      estimate: const PriceQuote(lines: [
        QuoteLine(
            sku: 'SKU001',
            name: 'Product',
            qty: 10,
            unitPrice: 100,
            discount: 0)
      ], applied: [], total: 1000, discount: 0),
      estimatedAt: DateTime.now(),
      snapshot: null,
      pendingOnlineRequest: request,
    );
    expect(draft.clientRequestId, request.clientOrderKey);
    await database.close();
    final restored =
        (await queue.byId(draft.clientRequestId, ownerId: 'sales'))!;
    expect(SyncQueueLogic.canEdit(restored), isFalse);
    expect(SyncQueueLogic.canSend(restored, DateTime.now()), isTrue);
    await expectLater(
        queue.deleteDraft(restored.clientRequestId, ownerId: 'sales'),
        throwsA(isA<ApiException>()));
    final sending = await queue.claimForSend(restored.clientRequestId,
        ownerId: 'sales', now: DateTime.now());
    final result = await api.submitOffline(sending.payload);
    expect(result.orderCode, 'SO-EXISTING');
    expect(transport.uniqueOrders, 1);
    expect(transport.requests.map((request) => request.path),
        ['/orders', '/orders']);
    expect(transport.requests[1].body, transport.requests[0].body);
    expect(sending.payload.toRequestJson(), request.toJson());
  });
}

class _LostResponseTransport implements ApiTransport {
  final requests = <ApiRequest>[];
  final committed = <String, String>{};
  int get uniqueOrders => committed.length;

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    final body = request.body as Map;
    final key = body['clientOrderKey'] as String;
    final original = committed[key];
    if (original == null) {
      committed[key] = jsonEncode(body);
      throw const ApiException.network();
    }
    expect(jsonEncode(body), original);
    return const ApiResponse(statusCode: 200, data: {
      'id': 'server-order',
      'orderCode': 'SO-EXISTING',
      'source': 'Online',
      'status': 'Quoted',
      'finalAmount': 1000
    });
  }
}
