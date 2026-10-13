import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/picking.dart';

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
    required int lineIndex,
    required String labelCode,
    required int qty,
  }) async {
    final data = await _client.post(
      Endpoints.pickingListScan(code),
      body: <String, dynamic>{
        'lineIndex': lineIndex,
        'labelCode': labelCode,
        'qty': qty
      },
    );
    return PickScanResult.fromJson(asMap(data));
  }

  /// "Xác nhận đã xuất": deducts stock, labels become InTransit.
  Future<PickingList> ship(String code) async {
    final data = await _client.post(Endpoints.pickingListShip(code));
    return PickingList.fromJson(asMap(data));
  }
}
