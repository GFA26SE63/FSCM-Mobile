import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/core/printing/label_printer.dart';
import 'package:fscm_mobile/core/printing/print_session.dart';
import 'package:fscm_mobile/data/remote/picking_api.dart';
import 'package:fscm_mobile/data/models/enums.dart';

class _Transport implements ApiTransport {
  _Transport(this.handle);
  final Future<ApiResponse> Function(ApiRequest) handle;
  final requests = <ApiRequest>[];
  @override
  Future<ApiResponse> send(ApiRequest request) {
    requests.add(request);
    return handle(request);
  }
}

Map<String, dynamic> response(ApiRequest request,
        {bool whole = false, bool missingReplacement = false}) =>
    {
      'pickingCode': 'PK-DH-001-WH',
      'status': 'InProgress',
      'version': 2,
      'items': [],
      'scans': [
        {
          'operationKey': request.headers['Idempotency-Key'],
          'qrCode': whole ? 'TEM-000001' : 'TEM-000002',
          'quantity': whole ? 50 : 25,
          'sourceQrCode': 'TEM-000001',
          'replacementQrCode':
              whole || missingReplacement ? null : 'TEM-000003',
          'replacementQuantity': whole || missingReplacement ? 0 : 25
        },
        // Never infer B by choosing the last scan: another operation can appear later.
        {
          'operationKey': 'other-operation',
          'qrCode': 'TEM-000099',
          'quantity': 3
        },
      ],
    };

Future<dynamic> scan(PickingApi api, {int quantity = 25}) =>
    api.scan('PK-DH-001-WH',
        allocationId: 'allocation',
        labelCode: 'TEM-000001',
        qty: quantity,
        sourceLabelQty: 50,
        pickingVersion: 1,
        labelVersion: 1);

void main() {
  test(
      'partial scan uses B for delivery and C for replacement, never A or the last scan',
      () async {
    final transport = _Transport((request) async =>
        ApiResponse(statusCode: 200, data: response(request)));
    final client = ApiClient(transport: transport, tokenReader: () => 'token');
    addTearDown(client.dispose);
    final result = await scan(PickingApi(client));
    expect(result.sourceLabel, 'TEM-000001');
    expect(result.childLabel, 'TEM-000002');
    expect(result.remainingLabel, 'TEM-000003');
    expect(result.pickedQty, 25);
    expect(result.remainingQty, 25);
    expect(LabelStatus.fromCode('Split'), LabelStatus.split);
  });

  test('a lost scan response retries the same operation key and body',
      () async {
    var calls = 0;
    final transport = _Transport((request) async {
      if (calls++ == 0) throw const ApiException.timeout();
      return ApiResponse(statusCode: 200, data: response(request));
    });
    final client = ApiClient(transport: transport, tokenReader: () => 'token');
    addTearDown(client.dispose);
    final api = PickingApi(client);
    await expectLater(scan(api), throwsA(isA<ApiException>()));
    final result = await scan(api);
    expect(result.remainingLabel, 'TEM-000003');
    expect(transport.requests[0].headers['Idempotency-Key'],
        transport.requests[1].headers['Idempotency-Key']);
    expect(transport.requests[0].body, transport.requests[1].body);
  });

  test('missing C is an error, not a fabricated result that reuses A',
      () async {
    var calls = 0;
    final transport = _Transport((request) async => ApiResponse(
        statusCode: 200,
        data: response(request, missingReplacement: calls++ == 0)));
    final client = ApiClient(transport: transport, tokenReader: () => null);
    addTearDown(client.dispose);
    final api = PickingApi(client);
    await expectLater(scan(api), throwsA(isA<ApiException>()));
    expect((await scan(api)).remainingLabel, 'TEM-000003');
    expect(transport.requests[0].headers['Idempotency-Key'],
        transport.requests[1].headers['Idempotency-Key']);
  });

  test('taking the entire source uses A with no B/C replacement', () async {
    final transport = _Transport((request) async =>
        ApiResponse(statusCode: 200, data: response(request, whole: true)));
    final client = ApiClient(transport: transport, tokenReader: () => null);
    addTearDown(client.dispose);
    final result = await scan(PickingApi(client), quantity: 50);
    expect(result.childLabel, 'TEM-000001');
    expect(result.remainingLabel, isEmpty);
    expect(result.pickedQty, 50);
  });

  test(
      'printing B/C fetches authenticated server HTML and opens a real print session',
      () async {
    final sessions = <_Session>[];
    final transport = _Transport((request) async => const ApiResponse(
        statusCode: 200, data: '<html><body>Official label</body></html>'));
    final client = ApiClient(transport: transport, tokenReader: () => 'token');
    addTearDown(client.dispose);
    final printer = LabelPrinter(client, openSession: () {
      final session = _Session();
      sessions.add(session);
      return session;
    });
    await printer.printLabel('TEM-000002');
    await printer.printLabel('TEM-000003');
    expect(transport.requests.map((r) => r.path),
        ['/qr-labels/TEM-000002/print', '/qr-labels/TEM-000003/print']);
    expect(transport.requests.first.headers['Authorization'], 'Bearer token');
    expect(sessions.map((s) => s.title), ['TEM-000002', 'TEM-000003']);
    expect(
        sessions.every((s) => s.html.contains('Official label') && !s.closed),
        isTrue);
  });

  test(
      'invalid server print document closes the session without claiming it printed',
      () async {
    final session = _Session();
    final transport = _Transport((request) async =>
        const ApiResponse(statusCode: 200, data: {'error': 'invalid'}));
    final client = ApiClient(transport: transport, tokenReader: () => null);
    addTearDown(client.dispose);
    final printer = LabelPrinter(client, openSession: () => session);
    await expectLater(
        printer.printLabel('TEM-000002'), throwsA(isA<ApiException>()));
    expect(session.closed, isTrue);
    expect(session.html, isEmpty);
  });
}

class _Session implements PrintSession {
  String html = '';
  String title = '';
  bool closed = false;
  @override
  Future<void> showHtml(String html, String title) async {
    this.html = html;
    this.title = title;
  }

  @override
  void close() {
    closed = true;
  }
}
