import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/picking.dart';
import 'package:uuid/uuid.dart';

final pickingApiProvider =
    Provider<PickingApi>((ref) => PickingApi(ref.watch(apiClientProvider)));

class PickingApi {
  PickingApi(this._client);

  final ApiClient _client;

  /// Picking lists of the Warehouse Keeper's warehouse.
  Future<List<PickingList>> list({String? status}) async {
    final data = await _client.get(
      Endpoints.pickingLists,
      query: <String, dynamic>{'status': status},
    );
    return unwrapItems(data).map(PickingList.fromJson).toList();
  }

  Future<PickingList> get(String code) async {
    final data = await _client.get(Endpoints.pickingList(code));
    return PickingList.fromJson(asMap(data));
  }

  /// Scan the source label of a line and take [qty] cartons from it. The
  /// server splits the label when qty < label quantity (child label).
  Future<PickScanResult> scan(
    String code, {
    required String allocationId,
    required String labelCode,
    required int qty,
    required int sourceLabelQty,
    required int pickingVersion,
    required int labelVersion,
  }) async {
    final data = await _client.post(
      Endpoints.pickingListScan(code),
      body: <String, dynamic>{
        'qrCode': labelCode,
        'quantity': qty,
        'expectedPickingVersion': pickingVersion,
        'expectedLabelVersion': labelVersion,
        'splits': <Map<String, dynamic>>[
          <String, dynamic>{
            'allocationRunAllocationId': allocationId,
            'quantity': qty,
          }
        ],
      },
      headers: <String, String>{'Idempotency-Key': const Uuid().v4()},
    );
    final list = PickingList.fromJson(asMap(data));
    final child = list.scanCodes.isEmpty ? labelCode : list.scanCodes.last;
    return PickScanResult(
      list: list,
      childLabel: child,
      remainingLabel: child == labelCode ? '' : labelCode,
      remainingQty: sourceLabelQty - qty,
      pickedQty: qty,
    );
  }

  /// Closes the picking list. Inventory is deducted later at shipment issue.
  Future<PickingList> complete(String code, int expectedVersion) async {
    final data = await _client.post(
      Endpoints.pickingListComplete(code),
      body: <String, dynamic>{
        'expectedPickingVersion': expectedVersion,
        'exceptionType': null,
        'note': 'Warehouse Keeper completed picking on mobile.',
      },
    );
    return PickingList.fromJson(asMap(data));
  }
}
