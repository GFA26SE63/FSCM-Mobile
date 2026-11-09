import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/offline_expected_condition.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/data/models/order.dart';

OfflineOrder submissionDraft() {
  final at = DateTime.utc(2026, 11, 9, 1);
  final payload = OfflineOrderPayload(
    clientRequestId: '11111111-1111-4111-8111-111111111111',
    offlineCode: 'OFF-TEST-0001',
    retailerId: '22222222-2222-4222-8222-222222222222',
    retailerCode: 'RT001',
    retailerName: 'Retailer',
    createdAt: at,
    lines: const [
      CartLine(
        productId: '33333333-3333-4333-8333-333333333333',
        sku: 'SKU001',
        qty: 10,
      )
    ],
    localTotal: 1000,
    localDiscount: 0,
    snapshotVersion: 'snapshot-1',
    expectedConditions: const [
      OfflineExpectedCondition(
        productId: '33333333-3333-4333-8333-333333333333',
        expectedBaseUnitPrice: 100,
        expectedMlorVersion: 1,
        expectedMlorRatio: 0.5,
      )
    ],
  );
  return OfflineOrder(
    clientRequestId: payload.clientRequestId,
    payload: payload,
    status: SyncStatus.pending,
    createdAt: at,
  );
}

Map<String, dynamic> submissionConflictJson() => {
      'clientOrderKey': '11111111-1111-4111-8111-111111111111',
      'snapshotVersion': 'snapshot-1',
      'offlineEstimatedAmount': 1000,
      'currentIndicativeAmount': 1100,
      'requiresExplicitConfirmation': true,
      'changedLines': [
        {
          'productId': '33333333-3333-4333-8333-333333333333',
          'sku': 'SKU001',
          'expectedBaseUnitPrice': 100,
          'currentBaseUnitPrice': 110,
          'expectedMlorVersion': 1,
          'currentMlorVersion': 2,
          'expectedMlorRatio': 0.5,
          'currentMlorRatio': 0.6,
        }
      ],
    };
