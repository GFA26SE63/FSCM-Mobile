import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/data/remote/orders_api.dart';

import 'fixtures/offline_submission_fixture.dart';

void main() {
  test(
      'confirmation resubmits the same original key and payload with only explicit consent changed',
      () async {
    final transport = _SubmissionTransport();
    final client =
        ApiClient(transport: transport, tokenReader: () => 'test-token');
    addTearDown(client.dispose);
    final api = OrdersApi(client);
    final draft = submissionDraft();

    await expectLater(
        api.submitOffline(draft.payload),
        throwsA(isA<ApiException>()
            .having((error) => error.statusCode, 'status', 409)
            .having((error) => error.problemDetails?['details'], 'details',
                isNotNull)));
    final result =
        await api.submitOffline(draft.payload, confirmConditionChanges: true);
    expect(result.orderCode, 'SO-NEW');
    expect(result.serverOrder, isNotNull);
    expect(transport.requests.map((request) => request.path),
        [Endpoints.ordersSync, Endpoints.ordersSync]);
    final first =
        Map<String, dynamic>.from(transport.requests.first.body! as Map);
    final second =
        Map<String, dynamic>.from(transport.requests.last.body! as Map);
    expect(first.remove('confirmConditionChanges'), isFalse);
    expect(second.remove('confirmConditionChanges'), isTrue);
    expect(second, first);
  });
}

class _SubmissionTransport implements ApiTransport {
  final requests = <ApiRequest>[];

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    if (requests.length == 1) {
      return ApiResponse(statusCode: 409, data: {
        'code': 'conflict',
        'title': 'Conditions changed',
        'details': submissionConflictJson(),
      });
    }
    return const ApiResponse(statusCode: 201, data: {
      'orderCode': 'SO-NEW',
      'source': 'Offline',
      'status': 'Allocating',
      'finalAmount': 1100,
    });
  }
}
