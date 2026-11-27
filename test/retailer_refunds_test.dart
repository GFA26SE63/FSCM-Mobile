import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/core/auth/screen_permissions.dart';
import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/config/env.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/finance_repository.dart';

class _Transport implements ApiTransport {
  _Transport(this.onGraphQl);

  final ApiResponse Function(String operation, Map<String, dynamic> variables)
      onGraphQl;
  final List<String> operations = <String>[];

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    if (request.path != Env.effectiveGraphQlEndpoint) {
      throw StateError('unexpected REST call ${request.path}');
    }
    final body = request.body! as Map;
    final operation = body['operationName'] as String;
    operations.add(operation);
    return onGraphQl(operation,
        Map<String, dynamic>.from((body['variables'] ?? const {}) as Map));
  }
}

ApiResponse _data(Map<String, dynamic> data) =>
    ApiResponse(statusCode: 200, data: <String, dynamic>{'data': data});

ApiResponse _forbidden() => const ApiResponse(statusCode: 200, data: <String, dynamic>{
      'data': null,
      'errors': <Map<String, dynamic>>[
        <String, dynamic>{
          'message': 'Access denied.',
          'extensions': <String, dynamic>{'code': 'AUTH_NOT_AUTHORIZED'},
        },
      ],
    });

Map<String, dynamic> _refund(String id, String status) => <String, dynamic>{
      'id': id,
      'amount': 150000,
      'status': status,
      'transferredAt': null,
      'transactionReference': status == 'Refunded' ? 'FT123' : null,
      'verifiedAt': null,
      'reason': 'Claim KN-1',
    };

Map<String, dynamic> _order(String orderId, String code, String method,
        List<Map<String, dynamic>> refunds) =>
    <String, dynamic>{
      'id': 'pay-$orderId',
      'orderId': orderId,
      'orderCode': code,
      'paymentMethod': method,
      'refunds': refunds,
    };

const _retailer =
    AppUser(id: 'u1', fullName: 'R', phone: '0', role: UserRole.retailer);

Future<List<dynamic>> _load(_Transport t) async {
  final client = ApiClient(transport: t, tokenReader: () => 'token');
  addTearDown(client.dispose);
  final container = ProviderContainer(overrides: [
    currentUserProvider.overrideWithValue(_retailer),
    apiClientProvider.overrideWithValue(client),
  ]);
  addTearDown(container.dispose);
  final sub = container.listen(retailerRefundsProvider, (_, __) {});
  addTearDown(sub.close);
  return container.read(retailerRefundsProvider.future);
}

void main() {
  test('merges Credit refunds with refunds of prepaid claim orders', () async {
    final t = _Transport((operation, variables) => switch (operation) {
          'RetailerRefunds' => _data(<String, dynamic>{
              'retailerReceivables': <String, dynamic>{
                'items': <Map<String, dynamic>>[
                  _order('o1', 'DH-001', 'Credit',
                      <Map<String, dynamic>>[_refund('r1', 'Refunded')]),
                  _order('o2', 'DH-002', 'Credit', <Map<String, dynamic>>[]),
                ],
                'page': 1,
                'pageSize': 100,
                'totalCount': 2,
                'totalPages': 1,
              },
            }),
          'Complaints' => _data(<String, dynamic>{
              'entities': <String, dynamic>{
                'complaintReads': <Map<String, dynamic>>[
                  // Credit order already loaded: no extra call.
                  <String, dynamic>{'id': 'c1', 'refundId': 'r1', 'salesOrderId': 'o1'},
                  <String, dynamic>{'id': 'c2', 'refundId': 'r2', 'salesOrderId': 'o3'},
                  <String, dynamic>{'id': 'c3', 'refundId': 'r2', 'salesOrderId': 'o3'},
                  <String, dynamic>{'id': 'c4', 'refundId': '', 'salesOrderId': 'o4'},
                ],
              },
            }),
          'RetailerOrderRefunds' => _data(<String, dynamic>{
              'retailerReceivable': _order(variables['orderId'] as String,
                  'DH-003', 'Prepaid', <Map<String, dynamic>>[
                _refund('r2', 'EvidenceRejected'),
              ]),
            }),
          _ => throw StateError(operation),
        });

    final refunds = await _load(t);

    expect(t.operations.where((o) => o == 'RetailerOrderRefunds').length, 1);
    expect(refunds.map((r) => r.id), <String>['r2', 'r1']); // open first
    expect(refunds.first.orderCode, 'DH-003');
    expect(refunds.first.paymentText, 'Trả trước');
    expect(refunds.first.statusText, 'Bằng chứng bị trả lại');
    expect(refunds.last.transactionReference, 'FT123');
  });

  test('lists Credit refunds when the claims screen is not granted', () async {
    final t = _Transport((operation, _) => switch (operation) {
          'RetailerRefunds' => _data(<String, dynamic>{
              'retailerReceivables': <String, dynamic>{
                'items': <Map<String, dynamic>>[
                  _order('o1', 'DH-001', 'Credit',
                      <Map<String, dynamic>>[_refund('r1', 'PendingRefund')]),
                ],
                'totalCount': 1,
                'totalPages': 1,
              },
            }),
          'Complaints' => _forbidden(),
          _ => throw StateError(operation),
        });

    final refunds = await _load(t);

    expect(refunds.map((r) => r.id), <String>['r1']);
  });

  test('refund page uses the retailer payments screen grant', () {
    expect(screenPermissionFor('/retailer/refunds'), 'mobile-rt-payments');
  });
}
