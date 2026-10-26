import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/data/models/label_info.dart';
import 'package:fscm_mobile/data/models/run_picking.dart';
import 'package:fscm_mobile/data/models/shipment.dart';
import 'package:fscm_mobile/data/models/transfer.dart';
import 'package:fscm_mobile/data/remote/labels_api.dart';
import 'package:fscm_mobile/data/remote/picking_api.dart';
import 'package:fscm_mobile/data/remote/shipments_api.dart';
import 'package:fscm_mobile/data/remote/transfers_api.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';

final warehouseRepositoryProvider = Provider<WarehouseRepository>((ref) {
  return WarehouseRepository(
    picking: ref.watch(pickingApiProvider),
    shipments: ref.watch(shipmentsApiProvider),
    transfers: ref.watch(transfersApiProvider),
    labels: ref.watch(labelsApiProvider),
  );
});

final pickingListsProvider =
    FutureProvider.autoDispose<List<RunPickingSheet>>((ref) {
  ref.watch(dataVersionProvider);
  ref.watch(currentUserProvider);
  return ref.watch(warehouseRepositoryProvider).pickingSheets();
});

final pickingDetailProvider =
    FutureProvider.autoDispose.family<RunPickingSheet, String>((ref, code) {
  ref.watch(dataVersionProvider);
  return ref.watch(warehouseRepositoryProvider).pickingSheet(code);
});

/// What the issue screen needs about one order: the server's readiness verdict
/// and the order's per-warehouse parts.
typedef OrderIssueView = ({
  OrderShipmentReadiness readiness,
  List<Shipment> shipments,
});

/// F93/F96, fetched together and kept out of [pickingDetailProvider] on
/// purpose.
///
/// Readiness changes when another warehouse picks or a payment clears, neither
/// of which touches this sheet, so it cannot ride along with the sheet's own
/// cache. The parts come with it because the confirmation has to send the
/// part's version back and the readiness result does not carry one.
final orderIssueProvider = FutureProvider.autoDispose
    .family<OrderIssueView, String>((ref, orderId) async {
  ref.watch(dataVersionProvider);
  final repository = ref.watch(warehouseRepositoryProvider);
  final readiness = await repository.orderReadiness(orderId);
  final shipments = await repository.orderShipments(orderId);
  return (readiness: readiness, shipments: shipments);
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

/// Run picking, order issue, transfers and label lookup of the Warehouse
/// Keeper.
class WarehouseRepository {
  WarehouseRepository({
    required PickingApi picking,
    required ShipmentsApi shipments,
    required TransfersApi transfers,
    required LabelsApi labels,
  })  : _picking = picking,
        _shipments = shipments,
        _transfers = transfers,
        _labels = labels;

  final PickingApi _picking;
  final ShipmentsApi _shipments;
  final TransfersApi _transfers;
  final LabelsApi _labels;

  Future<List<RunPickingSheet>> pickingSheets({String? status}) =>
      _picking.list(status: status);

  Future<RunPickingSheet> pickingSheet(String pickingCode) =>
      _picking.get(pickingCode);

  Future<RunPickingSheet> pick(
    String pickingCode, {
    required String operationKey,
    required String qrCode,
    required int expectedPickingVersion,
    required int expectedLabelVersion,
    required List<RunPickingSplitQuantity> splits,
    double? quantity,
  }) =>
      _picking.scan(
        pickingCode,
        operationKey: operationKey,
        qrCode: qrCode,
        expectedPickingVersion: expectedPickingVersion,
        expectedLabelVersion: expectedLabelVersion,
        splits: splits,
        quantity: quantity,
      );

  Future<RunPickingSheet> completeSheet(
    String pickingCode, {
    required int expectedPickingVersion,
    String? exceptionType,
    String? note,
  }) =>
      _picking.complete(
        pickingCode,
        expectedPickingVersion: expectedPickingVersion,
        exceptionType: exceptionType,
        note: note,
      );

  Future<OrderShipmentReadiness> orderReadiness(String orderId) =>
      _shipments.readiness(orderId);

  Future<List<Shipment>> orderShipments(String orderId) =>
      _shipments.list(orderId: orderId);

  Future<Shipment> confirmIssue(String shipmentId, {required int version}) =>
      _shipments.confirmIssue(shipmentId, expectedVersion: version);

  Future<List<Transfer>> transfers({String? status, String? kind}) =>
      _transfers.list(status: status, kind: kind);

  Future<Transfer> transfer(String code) => _transfers.get(code);

  Future<Transfer> receiveTransfer(String code, List<String> labelCodes) =>
      _transfers.receive(code, labelCodes: labelCodes);

  Future<LabelInfo> label(String code) => _labels.get(code);
}
