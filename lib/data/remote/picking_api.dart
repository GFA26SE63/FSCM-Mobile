import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/picking.dart';
import 'package:uuid/uuid.dart';

final pickingApiProvider =
    Provider<PickingApi>((ref) => PickingApi(ref.watch(apiClientProvider)));

class PickingApi {
  PickingApi(this._client);

  final ApiClient _client;
  final Map<String, String> _pendingScans = <String, String>{};

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
    final body = <String, dynamic>{
      'qrCode': labelCode,
      'quantity': qty,
      'expectedPickingVersion': pickingVersion,
      'expectedLabelVersion': labelVersion,
      'splits': <Map<String, dynamic>>[
        <String, dynamic>{
          'allocationRunAllocationId': allocationId,
          'quantity': qty
        }
      ],
    };
    final signature = '$code:${jsonEncode(body)}';
    final key = _pendingScans.putIfAbsent(signature, () => const Uuid().v4());
    dynamic data;
    try {
      data = await _client.post(
        Endpoints.pickingListScan(code),
        body: body,
        headers: <String, String>{'Idempotency-Key': key},
      );
    } on ApiException catch (error) {
      if (error.kind != ApiErrorKind.network &&
          error.kind != ApiErrorKind.timeout) {
        _pendingScans.remove(signature);
      }
      rethrow;
    }
    final list = PickingList.fromJson(asMap(data));
    final scans = asMapList(asMap(data)['scans'])
        .where((scan) => asStr(scan['operationKey']) == key)
        .toList();
    if (scans.length != 1) {
      throw const ApiException(
          kind: ApiErrorKind.server,
          message:
              'Chưa nhận được đúng kết quả quét. Thử lại để lấy kết quả, không quét lại bằng mã khác.');
    }
    final scan = scans.single;
    final child = asStr(scan['qrCode']);
    final replacement = asStr(scan['replacementQrCode']);
    final replacementQty = asInt(scan['replacementQuantity']);
    if (child.isEmpty ||
        (qty < sourceLabelQty &&
            (replacement.isEmpty ||
                replacement == labelCode ||
                replacement == child ||
                replacementQty <= 0))) {
      throw const ApiException(
          kind: ApiErrorKind.server,
          message:
              'Máy chủ chưa trả đủ hai tem giao hàng và thay thế. Thử lại để kiểm tra kết quả.');
    }
    _pendingScans.remove(signature);
    return PickScanResult(
      list: list,
      childLabel: child,
      sourceLabel: asStr(scan['sourceQrCode']).isEmpty
          ? labelCode
          : asStr(scan['sourceQrCode']),
      remainingLabel: replacement,
      remainingQty: replacementQty,
      pickedQty: asInt(scan['quantity']),
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
