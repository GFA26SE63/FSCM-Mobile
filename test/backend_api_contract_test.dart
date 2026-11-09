import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/data/remote/orders_api.dart';
import 'package:fscm_mobile/data/remote/receivables_api.dart';
import 'package:fscm_mobile/data/remote/products_api.dart';
import 'package:fscm_mobile/data/remote/sync_api.dart';

const retailerId = '00000000-0000-0000-0000-000000000001';
const productId = '00000000-0000-0000-0000-000000000002';
const orderId = '00000000-0000-0000-0000-000000000003';
const key = '00000000-0000-0000-0000-000000000004';

// Fixtures follow OrdersController, PaymentsController, MobileSnapshotResult and
// PricingController. Exercise real API mode, independently of the demo handlers.
class BackendContractTransport implements ApiTransport {
  final requests = <ApiRequest>[];
  final Map<String, dynamic> payment = {
    'orderId': orderId,
    'orderCode': 'DH-000001',
    'retailerCode': 'DL-001',
    'retailerName': 'Shop',
    'amount': 900000,
    'status': 'Unpaid',
    'version': 3,
    'creditTermDays': 14,
    'deliveredDate': '2026-11-09',
    'dueDate': '2026-11-23'
  };
  @override
  Future<ApiResponse> send(ApiRequest r) async {
    requests.add(r);
    if (r.method == 'GET' && r.path == '/retailers') {
      return const ApiResponse(statusCode: 200, data: {
        'items': [
          {'id': retailerId, 'code': 'DL-001'}
        ]
      });
    }
    if (r.method == 'GET' && r.path == '/products') {
      return const ApiResponse(statusCode: 200, data: {
        'items': [
          {'id': productId, 'sku': 'SKU001'}
        ]
      });
    }
    if (r.method == 'GET' && r.path == '/pricing/snapshot') {
      expect(r.query!['productId'], productId);
      expect(r.query!['retailerId'], retailerId);
      expect(r.query!['quantity'], 10);
      return const ApiResponse(statusCode: 200, data: {
        'sku': 'SKU001',
        'productName': 'Milk',
        'quantity': 10,
        'unitPrice': 100000,
        'grossAmount': 1000000,
        'discountAmount': 100000,
        'discountPercent': 10
      });
    }
    if (r.method == 'GET' && r.path == '/receivables') {
      return ApiResponse(statusCode: 200, data: [payment]);
    }
    if (r.method == 'POST' && r.path == '/payments/orders/$orderId/collect') {
      final body = r.body as Map;
      expect(body['collectionMethod'], 'Cash');
      expect(body['expectedVersion'], 3);
      expect(r.headers['Idempotency-Key'], isNotEmpty);
      return ApiResponse(
          statusCode: 200,
          data: {...payment, 'status': 'Paid', 'paidDate': '2026-11-09'});
    }
    if (r.method == 'POST' &&
        (r.path == '/orders' || r.path == '/orders/sync')) {
      final body = r.body as Map;
      expect(body['clientOrderKey'], isNotEmpty);
      expect(body['retailerId'], retailerId);
      expect(body['paymentMethod'], 'Credit');
      expect(body['lines'], [
        {'productId': productId, 'quantity': 10}
      ]);
      expect(body.containsKey('orders'), isFalse);
      if (r.path.endsWith('/sync')) {
        expect(body['offlineEstimatedAmount'], 900000);
      }
      return const ApiResponse(statusCode: 201, data: {
        'id': orderId,
        'orderCode': 'DH-000001',
        'status': 'PendingApproval',
        'finalAmount': 900000,
        'hasOfflineDifference': false,
        'lines': []
      });
    }
    if (r.method == 'GET' && r.path == '/mobile/snapshot') {
      return const ApiResponse(statusCode: 200, data: {
        'generatedAt': '2026-11-09T10:00:00Z',
        'retailers': [
          {
            'id': retailerId,
            'code': 'DL-001',
            'name': 'Shop',
            'creditTermDays': 14
          }
        ],
        'categories': [
          {'id': 'cat', 'name': 'Dairy'}
        ],
        'products': [
          {
            'id': productId,
            'categoryId': 'cat',
            'sku': 'SKU001',
            'name': 'Milk',
            'unit': 'Carton',
            'shelfLifeHours': 720
          }
        ],
        'prices': [
          {
            'productId': productId,
            'unitPrice': 100000,
            'isActive': true,
            'effectiveFrom': '2026-11-01T00:00:00Z'
          }
        ],
        'indicativeStock': [
          {'productId': productId, 'indicativeAvailableQuantity': 100}
        ],
        'promotions': []
      });
    }
    return const ApiResponse(
        statusCode: 404, data: {'detail': 'Unsupported backend route'});
  }
}

OfflineOrderPayload offline({bool onlineAttempt = false}) =>
    OfflineOrderPayload(
        clientRequestId: key,
        offlineCode: 'OFF-TEST-0001',
        retailerCode: 'DL-001',
        retailerName: 'Shop',
        createdAt: DateTime.utc(2026, 11, 9),
        payment: PaymentMethod.credit,
        creditTerm: 14,
        lines: const [CartLine(sku: 'SKU001', qty: 10)],
        localTotal: 1000000,
        localDiscount: 100000,
        onlineAttempt: onlineAttempt);

void main() {
  late BackendContractTransport backend;
  late ApiClient client;
  setUp(() {
    backend = BackendContractTransport();
    client = ApiClient(transport: backend, tokenReader: () => 'test-token');
  });
  tearDown(() => client.dispose());
  test(
      'online create resolves identifiers and retries with the same client key',
      () async {
    final api = OrdersApi(client, useMock: false);
    const request = NewOrderRequest(
        clientOrderKey: key,
        retailerCode: 'DL-001',
        lines: [CartLine(sku: 'SKU001', qty: 10)],
        payment: PaymentMethod.credit);
    final result = await api.create(request);
    await api.create(request);
    expect(result.code, 'DH-000001');
    final sent = backend.requests.where((r) => r.method == 'POST').toList();
    expect(sent.length, 2);
    expect((sent[0].body as Map)['clientOrderKey'],
        (sent[1].body as Map)['clientOrderKey']);
  });
  test(
      'offline queue sends one DTO per order and maps the single-order response',
      () async {
    final results =
        await OrdersApi(client, useMock: false).syncOffline([offline()]);
    expect(results.single.accepted, isTrue);
    expect(results.single.clientRequestId, key);
    expect(results.single.orderCode, 'DH-000001');
    expect(backend.requests.last.path, '/orders/sync');
  });
  test(
      'a timed-out online attempt preserves its endpoint and key after queue persistence',
      () async {
    final restored =
        OfflineOrderPayload.fromJson(offline(onlineAttempt: true).toJson());
    await OrdersApi(client, useMock: false).syncOffline([restored]);
    expect(backend.requests.last.path, '/orders');
    final body = backend.requests.last.body as Map;
    expect(body['clientOrderKey'], key);
    expect(body.containsKey('offlineEstimatedAmount'), isFalse);
  });
  test(
      'collection sends order GUID, version, cash method and idempotency header',
      () async {
    final result =
        await ReceivablesApi(client, useMock: false).collect('DH-000001');
    expect(result.isPaid, isTrue);
    expect(result.term, 14);
    expect(result.deliveredAt, isNotNull);
  });
  test('snapshot joins GUID-based price and stock rows to cached SKUs',
      () async {
    final result = await SyncApi(client, useMock: false).snapshot();
    expect(result.products.single.sku, 'SKU001');
    expect(result.products.single.basePrice, 100000);
    expect(result.prices.single.price, 100000);
    expect(result.stock.single.available, 100);
    expect(result.retailers.single.creditTerm, 14);
  });
  test('online pricing calls the backend snapshot for the resolved SKU',
      () async {
    final result = await ProductsApi(client, useMock: false).quote(
        retailerCode: 'DL-001',
        lines: const [CartLine(sku: 'SKU001', qty: 10)]);
    expect(result.finalAmount, 900000);
    expect(result.lines.single.qty, 10);
  });
}
