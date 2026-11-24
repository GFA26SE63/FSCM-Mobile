import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/core/utils/id_format.dart';
import 'package:fscm_mobile/data/remote/labels_api.dart';
import 'package:fscm_mobile/features/warehouse/documents/warehouse_documents_api.dart';

/// UI.7A.1: which identifier each QR workflow accepts. Format checks here only
/// pre-filter; eligibility (warehouse, shipment, batch, duplicate) is the
/// Backend's and is NOT exercised by these tests.
class _Recorder implements ApiTransport {
  final List<ApiRequest> requests = <ApiRequest>[];
  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    return const ApiResponse(statusCode: 200, data: <String, dynamic>{
      'document': <String, dynamic>{
        'id': 'd1',
        'code': 'PNK-1',
        'kind': 'Receipt',
        'status': 'Open',
        'version': 1
      },
      'lines': <dynamic>[],
      'cartons': <dynamic>[],
    });
  }
}

void main() {
  const pallet = 'PID-F01-20260827-A-0001-0001';
  const carton = 'CID-F01-20260827-A-0001-0001';
  const unit = 'UID-F01-20260827-A-0001-000001';

  test('identifier kinds are not interchangeable', () {
    expect(IdFormat.isCarton(carton), isTrue);
    expect(IdFormat.isCarton(pallet), isFalse);
    expect(IdFormat.isCarton(unit), isFalse);
    expect(IdFormat.isLabelCode(pallet), isFalse);
    expect(IdFormat.isLabel(carton), isFalse); // TEM check is unchanged
    expect(IdFormat.isLabel('TEM-000187'), isTrue);
  });

  group('label lookup (TEM or carton CID only)', () {
    late _Recorder transport;
    late LabelsApi api;
    setUp(() {
      transport = _Recorder();
      api = LabelsApi(ApiClient(transport: transport, tokenReader: () => 't'),
          canLookup: true);
    });

    test('a valid CID reaches the label endpoint, upper-cased and trimmed',
        () async {
      try {
        await api.getDetail(' ${carton.toLowerCase()}\n');
      } catch (_) {
        // The fake body is not a label; only the request matters here.
      }
      expect(transport.requests.single.path, endsWith('/qr-labels/$carton'));
    });

    test('pallet, unit, malformed and padded codes never reach the server',
        () async {
      for (final bad in [
        pallet,
        unit,
        'CID-F01-20260827-A-0001',
        '$carton extra',
        'hello',
        ''
      ]) {
        await expectLater(
            api.getDetail(bad),
            throwsA(isA<ApiException>()
                .having((e) => e.kind, 'kind', ApiErrorKind.validation)),
            reason: bad);
      }
      expect(transport.requests, isEmpty);
    });

    test('lookup stays role-gated', () async {
      final blocked = LabelsApi(
          ApiClient(transport: transport, tokenReader: () => 't'),
          canLookup: false);
      await expectLater(
          blocked.getDetail(carton),
          throwsA(isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.forbidden)));
      expect(transport.requests, isEmpty);
    });
  });

  group('warehouse documents send the scanned code untouched', () {
    late _Recorder transport;
    late WarehouseDocumentsApi api;
    late WarehouseWork work;
    setUp(() async {
      transport = _Recorder();
      api = WarehouseDocumentsApi(
          ApiClient(transport: transport, tokenReader: () => 't'));
      work = await api.get('d1');
      transport.requests.clear();
    });

    Map<String, dynamic> body() =>
        transport.requests.single.body! as Map<String, dynamic>;

    test('factory receipt scans a PALLET code via the pallet endpoint',
        () async {
      await api.scanPallet(work, pallet);
      expect(transport.requests.single.path, endsWith('/pallet-scans'));
      expect(body()['code'], pallet);
      expect(body()['source'], 'Camera');
    });

    test(
        'a CID is not rewritten into a pallet: it is sent as scanned and the '
        'server (ScanReceiptPalletAsync) rejects it', () async {
      await api.scanPallet(work, carton);
      expect(body()['code'], carton);
    });

    test(
        'carton workflows (issue / transfer receipt) send the CID as '
        'cartonId to the scans endpoint', () async {
      await api.scanCarton(work, carton);
      expect(transport.requests.single.path, endsWith('/scans'));
      expect(body()['cartonId'], carton);
    });
  });
}
