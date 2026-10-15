import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/data/models/label_info.dart';
import 'package:fscm_mobile/data/models/picking.dart';
import 'package:fscm_mobile/data/models/transfer.dart';
import 'package:fscm_mobile/data/remote/labels_api.dart';
import 'package:fscm_mobile/data/remote/picking_api.dart';
import 'package:fscm_mobile/data/remote/transfers_api.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';

final warehouseRepositoryProvider = Provider<WarehouseRepository>((ref) {
  return WarehouseRepository(
    picking: ref.watch(pickingApiProvider),
    transfers: ref.watch(transfersApiProvider),
    labels: ref.watch(labelsApiProvider),
  );
});

final pickingListsProvider =
    FutureProvider.autoDispose<List<PickingList>>((ref) {
  ref.watch(dataVersionProvider);
  ref.watch(currentUserProvider);
  return ref.watch(warehouseRepositoryProvider).pickingLists();
});

final pickingDetailProvider =
    FutureProvider.autoDispose.family<PickingList, String>((ref, code) {
  return ref.watch(warehouseRepositoryProvider).pickingList(code);
});

final transfersProvider = FutureProvider.autoDispose<List<Transfer>>((ref) {
  ref.watch(dataVersionProvider);
  ref.watch(currentUserProvider);
  return ref.watch(warehouseRepositoryProvider).transfers();
});

final transferDetailProvider =
    FutureProvider.autoDispose.family<Transfer, String>((ref, code) {
  return ref.watch(warehouseRepositoryProvider).transfer(code);
});

final labelProvider =
    FutureProvider.autoDispose.family<LabelInfo, String>((ref, code) {
  return ref.watch(warehouseRepositoryProvider).label(code);
});

/// Picking, transfers and label lookup of the Warehouse Keeper.
class WarehouseRepository {
  WarehouseRepository({
    required PickingApi picking,
    required TransfersApi transfers,
    required LabelsApi labels,
  })  : _picking = picking,
        _transfers = transfers,
        _labels = labels;

  final PickingApi _picking;
  final TransfersApi _transfers;
  final LabelsApi _labels;

  Future<List<PickingList>> pickingLists({String? status}) =>
      _picking.list(status: status);

  Future<PickingList> pickingList(String code) => _picking.get(code);

  Future<PickScanResult> pick(
    String code, {
    required int lineIndex,
    required String labelCode,
    required int qty,
  }) =>
      _picking.scan(code, lineIndex: lineIndex, labelCode: labelCode, qty: qty);

  Future<PickingList> ship(String code) => _picking.ship(code);

  Future<List<Transfer>> transfers({String? status, String? kind}) =>
      _transfers.list(status: status, kind: kind);

  Future<Transfer> transfer(String code) => _transfers.get(code);

  Future<Transfer> receiveTransfer(String code, List<String> labelCodes) =>
      _transfers.receive(code, labelCodes: labelCodes);

  Future<LabelInfo> label(String code) => _labels.get(code);
}
