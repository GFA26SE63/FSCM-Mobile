import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/run_picking.dart';

final pickingApiProvider =
    Provider<PickingApi>((ref) => PickingApi(ref.watch(apiClientProvider)));

/// F43/F44: the run picking sheets of the Warehouse Keeper's warehouse.
///
/// The server scopes the list by the caller's warehouse assignments, so no
/// warehouse identifier is sent: a keeper asking for sheets gets their own.
class PickingApi {
  PickingApi(this._client);

  final ApiClient _client;

  Future<List<RunPickingSheet>> list({String? status}) async {
    final data = await _client.get(
      Endpoints.pickingLists,
      query: <String, dynamic>{'status': status},
    );
    return unwrapItems(data).map(RunPickingSheet.fromJson).toList();
  }

  Future<RunPickingSheet> get(String pickingCode) async {
    final data = await _client.get(Endpoints.pickingList(pickingCode));
    return RunPickingSheet.fromJson(asMap(data));
  }

  /// Records one scanned label against the splits it is being spent on.
  ///
  /// [operationKey] must be the same string on every retry of the same physical
  /// scan - that is the whole point of it. The server remembers the key and
  /// replies with the unchanged sheet rather than taking the cartons twice, so
  /// a reply lost to a dead connection is safe to send again. Generating a
  /// fresh key per attempt would defeat it.
  ///
  /// [quantity] may be left out when the splits already say how much; the
  /// server rejects the call if the two disagree, which is deliberate: it means
  /// the caller has lost track of what it is picking.
  Future<RunPickingSheet> scan(
    String pickingCode, {
    required String operationKey,
    required String qrCode,
    required int expectedPickingVersion,
    required int expectedLabelVersion,
    required List<RunPickingSplitQuantity> splits,
    double? quantity,
  }) async {
    final data = await _client.post(
      Endpoints.pickingListScans(pickingCode),
      headers: <String, String>{'Idempotency-Key': operationKey},
      body: <String, dynamic>{
        'qrCode': qrCode,
        'quantity': quantity,
        'expectedPickingVersion': expectedPickingVersion,
        'expectedLabelVersion': expectedLabelVersion,
        'splits': <Map<String, dynamic>>[
          for (final split in splits)
            <String, dynamic>{
              'allocationRunAllocationId': split.allocationRunAllocationId,
              'quantity': split.quantity,
            },
        ],
      },
    );
    return RunPickingSheet.fromJson(asMap(data));
  }

  /// Closes this warehouse's portion of the run.
  ///
  /// This is the end of picking, not a dispatch: nothing leaves and no stock
  /// moves here. Passing [exceptionType] closes it as needing handling instead,
  /// which holds every part of every order on the sheet.
  Future<RunPickingSheet> complete(
    String pickingCode, {
    required int expectedPickingVersion,
    String? exceptionType,
    String? note,
  }) async {
    final data = await _client.post(
      Endpoints.pickingListComplete(pickingCode),
      body: <String, dynamic>{
        'expectedPickingVersion': expectedPickingVersion,
        'exceptionType': exceptionType,
        'note': note,
      },
    );
    return RunPickingSheet.fromJson(asMap(data));
  }
}
