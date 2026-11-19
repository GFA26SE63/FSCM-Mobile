import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/config/env.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/models/complaint.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/remote/complaints_api.dart';
import 'package:fscm_mobile/data/remote/loyalty_api.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/loyalty_repository.dart';

class _Transport implements ApiTransport {
  _Transport({this.onGraphQl, this.onRest});

  ApiResponse Function(String query)? onGraphQl;
  ApiResponse Function(ApiRequest request)? onRest;
  final List<ApiRequest> graphQl = <ApiRequest>[];
  final List<ApiRequest> rest = <ApiRequest>[];

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    if (request.path == Env.effectiveGraphQlEndpoint) {
      graphQl.add(request);
      final handler = onGraphQl;
      if (handler == null) throw StateError('unexpected GraphQL call');
      return handler((request.body! as Map)['query'] as String);
    }
    rest.add(request);
    final handler = onRest;
    if (handler == null) throw StateError('unexpected REST call');
    return handler(request);
  }

  String get query => (graphQl.last.body! as Map)['query'] as String;
  String get restCalls => rest.map((r) => '${r.method} ${r.path}').join(',');
}

ApiResponse _entities(String field, Object? value) =>
    ApiResponse(statusCode: 200, data: <String, dynamic>{
      'data': <String, dynamic>{
        'entities': <String, dynamic>{field: value},
      },
    });

ApiResponse _errors(String message, [String? code]) =>
    ApiResponse(statusCode: 200, data: <String, dynamic>{
      'data': null,
      'errors': <Map<String, dynamic>>[
        <String, dynamic>{
          'message': message,
          if (code != null) 'extensions': <String, dynamic>{'code': code},
        },
      ],
    });

ApiClient _client(_Transport t) {
  final client = ApiClient(transport: t, tokenReader: () => 'token');
  addTearDown(client.dispose);
  return client;
}

Map<String, dynamic> _complaint({String status = 'Open'}) => <String, dynamic>{
      'id': 'c-1',
      'code': 'KN-261119-01',
      'orderCode': 'DH-1',
      'sku': 'SKU-1',
      'productName': 'Sản phẩm',
      'expectedQuantity': 10,
      'actualQuantity': 7,
      'issueType': 'Missing',
      'status': status,
      'labelCode': 'LBL-1',
      'note': 'Thiếu 3 thùng',
      'createdAt': '2026-11-19T01:00:00Z',
      'response': 'Đã tiếp nhận',
      'finalUnitPrice': 90000,
      'adjustmentAmount': 270000,
      'financialAdjustmentApplied': true,
      'resolutionType': 'FinancialAdjustment',
      'reviewStatus': 'UnderReview',
      'evidenceRequestReason': 'Cần thêm ảnh',
      'requestType': 'Return',
      'settlementMethod': 'CashRefund',
      'approvedSettlementMethod': 'CashRefund',
      'requestedQuantity': 3,
      'approvedQuantity': 2,
      'handledQuantity': 1,
      'physicalHandlingCompleted': true,
      'debtOffsetAmount': 100000,
      'refundAmount': 170000,
      'refundId': 'rf-1',
      'documents': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'd-1',
          'code': 'TH-01',
          'kind': 'ReturnOrder',
          'status': 'Pending',
          'approvedQuantity': 2,
          'actualQuantity': null,
          'completedAt': null,
          'note': null,
          'evidenceReference': null,
        },
      ],
    };

Map<String, dynamic> _redemption({String status = 'Pending'}) =>
    <String, dynamic>{
      'id': 'r-1',
      'rewardCode': 'QUA-001',
      'rewardName': 'Quà A',
      'redeemedPoints': 200,
      'status': status,
      'createdAt': '2026-11-17T00:00:00Z',
      'quantity': 2,
      'quantityIsEstimated': false,
      'clientRequestId': 'key-1',
    };

const _retailer =
    AppUser(id: 'u1', fullName: 'R', phone: '0', role: UserRole.retailer);
const _sales =
    AppUser(id: 'u2', fullName: 'S', phone: '0', role: UserRole.sales);

void main() {
  group('Complaints', () {
    test('GraphQL query: complaintReads, no arguments, nothing REST', () async {
      final t = _Transport(
          onGraphQl: (_) => _entities('complaintReads', [_complaint()]));

      final rows = await ComplaintsApi(_client(t)).list();

      expect(rows, hasLength(1));
      expect(t.rest, isEmpty);
      expect(t.query, contains('entities'));
      expect(t.query, contains('complaintReads {'));
      // No filter, sort or paging arguments exist, as in REST.
      expect(t.query, isNot(contains('complaintReads(')));
      expect((t.graphQl.single.body! as Map)['operationName'], 'Complaints');
      expect(t.query, isNot(contains('evidenceUrl'))); // evidence stays REST
    });

    test('every displayed field is mapped', () async {
      final t = _Transport(
          onGraphQl: (_) => _entities('complaintReads', [_complaint()]));
      final c = (await ComplaintsApi(_client(t)).list()).single;

      expect(c.id, 'c-1');
      expect(c.code, 'KN-261119-01');
      expect(c.orderCode, 'DH-1');
      expect(c.sku, 'SKU-1');
      expect(c.name, 'Sản phẩm');
      expect(c.expectedQty, 10);
      expect(c.actualQty, 7);
      expect(c.shortfall, 3);
      expect(c.issueType, 'Missing');
      expect(c.labelCode, 'LBL-1');
      expect(c.note, 'Thiếu 3 thùng');
      expect(c.response, 'Đã tiếp nhận');
      expect(c.createdAt, DateTime.utc(2026, 11, 19, 1));
      expect(c.reviewStatus, 'UnderReview');
      expect(c.needsEvidence, isTrue);
      expect(c.evidenceRequestReason, 'Cần thêm ảnh');
      expect(c.resolutionType, 'FinancialAdjustment');
      expect(c.requestType, 'Return');
      expect(c.typeText, 'Trả hàng');
      expect(c.settlementMethod, 'CashRefund');
      expect(c.approvedSettlementMethod, 'CashRefund');
      expect(c.requestedQuantity, 3);
      expect(c.approvedQuantity, 2);
      expect(c.handledQuantity, 1);
      expect(c.physicalHandlingCompleted, isTrue);
      expect(c.financialAdjustmentApplied, isTrue);
      expect(c.finalUnitPrice, 90000);
      expect(c.adjustmentAmount, 270000);
      expect(c.debtOffsetAmount, 100000);
      expect(c.refundAmount, 170000);
      expect(c.refundId, 'rf-1');
      expect(c.documents.single['kind'], 'ReturnOrder');
      expect(c.documents.single['code'], 'TH-01');
      expect(c.documents.single['status'], 'Pending');
    });

    test('status mapping is unchanged', () async {
      final statuses = <String, ComplaintStatus>{
        'Open': ComplaintStatus.open,
        'InProgress': ComplaintStatus.inProgress,
        'Approved': ComplaintStatus.approved,
        'Resolved': ComplaintStatus.resolved,
        'Rejected': ComplaintStatus.rejected,
        'Cancelled': ComplaintStatus.cancelled,
        'SomethingNew': ComplaintStatus.open,
      };
      for (final entry in statuses.entries) {
        final t = _Transport(
            onGraphQl: (_) =>
                _entities('complaintReads', [_complaint(status: entry.key)]));
        final c = (await ComplaintsApi(_client(t)).list()).single;
        expect(c.status, entry.value, reason: entry.key);
      }
    });

    test('server order is kept and an empty list is empty', () async {
      final t = _Transport(
          onGraphQl: (_) => _entities('complaintReads', [
                {..._complaint(), 'id': 'b', 'code': 'KN-2'},
                {..._complaint(), 'id': 'a', 'code': 'KN-1'},
              ]));
      expect((await ComplaintsApi(_client(t)).list()).map((c) => c.id),
          ['b', 'a']);

      final empty =
          _Transport(onGraphQl: (_) => _entities('complaintReads', []));
      expect(await ComplaintsApi(_client(empty)).list(), isEmpty);
    });

    test('a malformed answer is an error, never an empty list', () async {
      final t = _Transport(
          onGraphQl: (_) => _entities('complaintReads', null),
          onRest: (_) => throw StateError('must not fall back'));
      await expectLater(
          ComplaintsApi(_client(t)).list(), throwsA(isA<ApiException>()));
    });

    test('generic error is re-read through REST; auth and network are not',
        () async {
      final t = _Transport(
        onGraphQl: (_) => _errors('Unexpected Execution Error'),
        onRest: (_) => ApiResponse(statusCode: 200, data: [_complaint()]),
      );
      expect(await ComplaintsApi(_client(t)).list(), hasLength(1));
      expect(t.restCalls, 'GET /complaints');

      final denied = _Transport(
          onGraphQl: (_) => _errors('no', 'AUTH_NOT_AUTHORIZED'),
          onRest: (_) => throw StateError('must not fall back'));
      await expectLater(
          ComplaintsApi(_client(denied)).list(),
          throwsA(isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.forbidden)));

      final offline = _Transport(
          onGraphQl: (_) => throw const ApiException.network(),
          onRest: (_) => throw StateError('must not fall back'));
      await expectLater(ComplaintsApi(_client(offline)).list(),
          throwsA(isA<ApiException>().having((e) => e.isNetwork, 'net', true)));
    });

    test('only a Retailer reads the list: other roles are refused locally',
        () async {
      // GraphQL complaintReads has no role gate and lists every complaint for
      // roles other than Retailer; REST refuses them. The app never asks.
      final t = _Transport(
          onGraphQl: (_) => _entities('complaintReads', [_complaint()]));
      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWithValue(_sales),
        apiClientProvider.overrideWithValue(_client(t)),
      ]);
      addTearDown(container.dispose);
      final sub = container.listen(complaintsProvider, (_, __) {});
      addTearDown(sub.close);

      await expectLater(container.read(complaintsProvider.future),
          throwsA(isA<ApiException>()));
      expect(t.graphQl, isEmpty);
      expect(t.rest, isEmpty);

      final ok = ProviderContainer(overrides: [
        currentUserProvider.overrideWithValue(_retailer),
        apiClientProvider.overrideWithValue(_client(t)),
      ]);
      addTearDown(ok.dispose);
      final sub2 = ok.listen(complaintsProvider, (_, __) {});
      addTearDown(sub2.close);
      expect(await ok.read(complaintsProvider.future), hasLength(1));
      expect(t.graphQl, hasLength(1));
    });

    test('writes and evidence stay REST', () async {
      final t = _Transport(
        onGraphQl: (_) => throw StateError('writes never use GraphQL'),
        onRest: (r) => r.method == 'DELETE'
            ? const ApiResponse(statusCode: 204)
            : ApiResponse(statusCode: 200, data: _complaint()),
      );
      final api = ComplaintsApi(_client(t));

      await api.create(const NewComplaint(
          orderCode: 'DH-1',
          sku: 'SKU-1',
          labelCode: 'LBL-1',
          actualQty: 7,
          issueType: 'Missing',
          note: 'n'));
      await api.cancel('c-1');
      await api.removeEvidence('c-1', 'e-1');

      expect(t.graphQl, isEmpty);
      expect(t.restCalls,
          'POST /complaints,POST /complaints/c-1/cancel,DELETE /complaints/c-1/evidence/e-1');
      expect((t.rest.first.body as Map).containsKey('requestId'), isTrue);
    });
  });

  group('Redemptions', () {
    test('GraphQL query: redemptionReads, no arguments, nothing REST',
        () async {
      final t = _Transport(
          onGraphQl: (_) => _entities('redemptionReads', [_redemption()]));

      final rows = await LoyaltyApi(_client(t)).redemptions();

      expect(rows, hasLength(1));
      expect(t.rest, isEmpty);
      expect(t.query, contains('redemptionReads {'));
      expect(t.query, isNot(contains('redemptionReads(')));
      expect((t.graphQl.single.body! as Map)['operationName'], 'Redemptions');
      // Retailer scope is the Backend's; nothing internal is requested.
      for (final field in <String>[
        'balanceAfter',
        'heldPoints',
        'regionId',
        'salesGroupIds',
        'retailerCode',
        'retailerName'
      ]) {
        expect(t.query, isNot(contains(field)));
      }
    });

    test('reward information, points, quantity and ids are mapped', () async {
      final t = _Transport(
          onGraphQl: (_) => _entities('redemptionReads', [
                {..._redemption(), 'quantityIsEstimated': true},
              ]));
      final r = (await LoyaltyApi(_client(t)).redemptions()).single;

      expect(r.code, 'r-1');
      expect(r.giftCode, 'QUA-001');
      expect(r.giftName, 'Quà A');
      expect(r.points, 200); // as the Backend reports it
      expect(r.quantity, 2);
      expect(r.quantityIsEstimated, isTrue);
      expect(r.clientRequestId, 'key-1');
      expect(r.requestedAt, DateTime.utc(2026, 11, 17));
    });

    test('status mapping is unchanged', () async {
      for (final code in <String>[
        'Pending',
        'Approved',
        'Delivered',
        'Rejected',
        'Completed',
        'FutureStatus',
      ]) {
        final t = _Transport(
            onGraphQl: (_) =>
                _entities('redemptionReads', [_redemption(status: code)]));
        final r = (await LoyaltyApi(_client(t)).redemptions()).single;
        expect(r.status, GiftRequestStatus.fromCode(code), reason: code);
      }
      expect(GiftRequestStatus.fromCode('FutureStatus'),
          GiftRequestStatus.unknown);
    });

    test('empty list; missing quantity is an error, not a record', () async {
      final empty =
          _Transport(onGraphQl: (_) => _entities('redemptionReads', []));
      expect(await LoyaltyApi(_client(empty)).redemptions(), isEmpty);

      final bad = _Transport(
          onGraphQl: (_) => _entities(
              'redemptionReads', [_redemption()..remove('quantity')]));
      await expectLater(
          LoyaltyApi(_client(bad)).redemptions(), throwsA(isA<ApiException>()));

      final malformed =
          _Transport(onGraphQl: (_) => _entities('redemptionReads', null));
      await expectLater(LoyaltyApi(_client(malformed)).redemptions(),
          throwsA(isA<ApiException>()));
    });

    test('generic error is re-read through REST; auth and network are not',
        () async {
      final t = _Transport(
        onGraphQl: (_) => _errors('Unexpected Execution Error'),
        onRest: (_) => ApiResponse(statusCode: 200, data: [_redemption()]),
      );
      expect(await LoyaltyApi(_client(t)).redemptions(), hasLength(1));
      expect(t.restCalls, 'GET /loyalty/redemptions');

      final denied = _Transport(
          onGraphQl: (_) => _errors('no', 'AUTH_NOT_AUTHENTICATED'),
          onRest: (_) => throw StateError('must not fall back'));
      await expectLater(LoyaltyApi(_client(denied)).redemptions(),
          throwsA(isA<ApiException>()));
      expect(denied.rest, isEmpty);

      final offline = _Transport(
          onGraphQl: (_) => throw const ApiException.timeout(),
          onRest: (_) => throw StateError('must not fall back'));
      await expectLater(LoyaltyApi(_client(offline)).redemptions(),
          throwsA(isA<ApiException>().having((e) => e.isNetwork, 'net', true)));
    });

    test('redeem stays REST with its idempotency key and exact body', () async {
      final t = _Transport(
        onGraphQl: (_) => throw StateError('writes never use GraphQL'),
        onRest: (_) => ApiResponse(statusCode: 200, data: _redemption()),
      );
      final r = await LoyaltyApi(_client(t))
          .redeem(rewardId: 'gift-1', quantity: 2, operationKey: 'key-1');

      expect(r.code, 'r-1');
      expect(t.graphQl, isEmpty);
      expect(t.restCalls, 'POST /loyalty/redemptions');
      expect(t.rest.single.headers['Idempotency-Key'], 'key-1');
      expect(t.rest.single.body, {'rewardId': 'gift-1', 'quantity': 2});
    });
  });
}
