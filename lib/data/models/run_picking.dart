import 'package:fscm_mobile/core/utils/quantity.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';

/// One order's share of a gather, as `GET /picking-lists/{code}` returns it.
///
/// The two identifiers are carried even though nothing on screen reads them in
/// full: [allocationRunAllocationId] is what a scan is posted against, and
/// [allocationPlanPriceId] points at the price the run approved for this part.
/// A split that loses them cannot be traced back to the money it belongs to,
/// and the Warehouse Keeper has no business recomputing that price here.
class RunPickingSplit {
  const RunPickingSplit({
    required this.id,
    required this.allocationRunAllocationId,
    required this.allocationPlanPriceId,
    required this.salesOrderId,
    required this.salesOrderLineId,
    required this.orderCode,
    required this.requiredQuantity,
    required this.pickedQuantity,
    required this.remainingQuantity,
  });

  factory RunPickingSplit.fromJson(Map<String, dynamic> j) => RunPickingSplit(
        id: asStr(j['id']),
        allocationRunAllocationId: asStr(j['allocationRunAllocationId']),
        allocationPlanPriceId: asStr(j['allocationPlanPriceId']),
        salesOrderId: asStr(j['salesOrderId']),
        salesOrderLineId: asStr(j['salesOrderLineId']),
        orderCode: asStr(j['orderCode']),
        requiredQuantity: asDouble(j['requiredQuantity']),
        pickedQuantity: asDouble(j['pickedQuantity']),
        remainingQuantity: asDouble(j['remainingQuantity']),
      );

  final String id;
  final String allocationRunAllocationId;
  final String allocationPlanPriceId;
  final String salesOrderId;
  final String salesOrderLineId;
  final String orderCode;
  final double requiredQuantity;
  final double pickedQuantity;
  final double remainingQuantity;

  bool get isDone => Qty.covers(pickedQuantity, requiredQuantity);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'allocationRunAllocationId': allocationRunAllocationId,
        'allocationPlanPriceId': allocationPlanPriceId,
        'salesOrderId': salesOrderId,
        'salesOrderLineId': salesOrderLineId,
        'orderCode': orderCode,
        'requiredQuantity': requiredQuantity,
        'pickedQuantity': pickedQuantity,
        'remainingQuantity': remainingQuantity,
      };
}

/// One trip to one batch: everything the sheet needs from it, for every order
/// at once. The batch is fixed by the approved plan - the sheet shows it so the
/// keeper can find the pallet, never so they can choose a different one.
class RunPickingGather {
  const RunPickingGather({
    required this.id,
    required this.productId,
    required this.sku,
    required this.batchId,
    required this.batchCode,
    required this.requiredQuantity,
    required this.pickedQuantity,
    required this.remainingQuantity,
    required this.status,
    required this.splits,
  });

  factory RunPickingGather.fromJson(Map<String, dynamic> j) => RunPickingGather(
        id: asStr(j['id']),
        productId: asStr(j['productId']),
        sku: asStr(j['sku']),
        batchId: asStr(j['batchId']),
        batchCode: asStr(j['batchCode']),
        requiredQuantity: asDouble(j['requiredQuantity']),
        pickedQuantity: asDouble(j['pickedQuantity']),
        remainingQuantity: asDouble(j['remainingQuantity']),
        status: GatherStatus.fromCode(asStrOrNull(j['status'])),
        splits: mapList(j['splits'], RunPickingSplit.fromJson),
      );

  final String id;
  final String productId;
  final String sku;
  final String batchId;
  final String batchCode;
  final double requiredQuantity;
  final double pickedQuantity;
  final double remainingQuantity;
  final GatherStatus status;
  final List<RunPickingSplit> splits;

  bool get isDone => status == GatherStatus.picked;

  /// The splits that still owe cartons, which is what a scan can be spent on.
  List<RunPickingSplit> get outstanding =>
      splits.where((s) => !s.isDone).toList();

  /// Spreads [quantity] over the splits that still owe cartons, front to back.
  ///
  /// The order matters and is not arbitrary: the server returns splits in the
  /// run's own priority order, so filling them front to back is what keeps
  /// first come first served when one scan cannot cover everyone. Spreading it
  /// evenly instead would quietly let a later order take cartons from an
  /// earlier one.
  ///
  /// Never hands out more than a split still owes, and stops once [quantity] is
  /// spent, so the result can be posted as-is.
  List<RunPickingSplitQuantity> apportion(double quantity) {
    final result = <RunPickingSplitQuantity>[];
    var left = quantity;
    for (final split in outstanding) {
      if (left <= 0) break;
      final owed = split.remainingQuantity;
      if (owed <= 0) continue;
      final take = left < owed ? left : owed;
      result.add(RunPickingSplitQuantity(
        allocationRunAllocationId: split.allocationRunAllocationId,
        quantity: take,
      ));
      left -= take;
    }
    return result;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'productId': productId,
        'sku': sku,
        'batchId': batchId,
        'batchCode': batchCode,
        'requiredQuantity': requiredQuantity,
        'pickedQuantity': pickedQuantity,
        'remainingQuantity': remainingQuantity,
        'status': status.code,
        'splits': splits.map((s) => s.toJson()).toList(),
      };
}

/// One scan already recorded on the sheet.
class RunPickingScan {
  const RunPickingScan({
    required this.operationKey,
    required this.qrCode,
    required this.quantity,
    required this.performedByUserId,
    this.occurredAt,
  });

  factory RunPickingScan.fromJson(Map<String, dynamic> j) => RunPickingScan(
        operationKey: asStr(j['operationKey']),
        qrCode: asStr(j['qrCode']),
        quantity: asDouble(j['quantity']),
        performedByUserId: asStr(j['performedByUserId']),
        occurredAt: asDate(j['occurredAt']),
      );

  final String operationKey;
  final String qrCode;
  final double quantity;
  final String performedByUserId;
  final DateTime? occurredAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'operationKey': operationKey,
        'qrCode': qrCode,
        'quantity': quantity,
        'performedByUserId': performedByUserId,
        'occurredAt': isoOrNull(occurredAt),
      };
}

/// F43: the picking sheet of one warehouse for one allocation run.
///
/// Not one sheet per order. A run approves allocations across every order it
/// filled, and the sheet is cut per warehouse: gather once per SKU/batch, then
/// split that pile back to the orders. [version] is what every write must send
/// back, so two keepers on the same sheet cannot overwrite each other.
class RunPickingSheet {
  const RunPickingSheet({
    required this.id,
    required this.pickingCode,
    required this.allocationRunId,
    required this.allocationPlanVersionId,
    required this.warehouseId,
    required this.status,
    required this.version,
    required this.gathers,
    this.assignedToUserId,
    this.issuedAt,
    this.startedAt,
    this.completedAt,
    this.completedByUserId,
    this.exceptionType,
    this.exceptionNote,
    this.scans = const <RunPickingScan>[],
  });

  factory RunPickingSheet.fromJson(Map<String, dynamic> j) => RunPickingSheet(
        id: asStr(j['id']),
        pickingCode: asStr(j['pickingCode']),
        allocationRunId: asStr(j['allocationRunId']),
        allocationPlanVersionId: asStr(j['allocationPlanVersionId']),
        warehouseId: asStr(j['warehouseId']),
        status: SheetStatus.fromCode(asStrOrNull(j['status'])),
        version: asInt(j['version']),
        gathers: mapList(j['gathers'], RunPickingGather.fromJson),
        assignedToUserId: asStrOrNull(j['assignedToUserId']),
        issuedAt: asDate(j['issuedAt']),
        startedAt: asDate(j['startedAt']),
        completedAt: asDate(j['completedAt']),
        completedByUserId: asStrOrNull(j['completedByUserId']),
        exceptionType: asStrOrNull(j['exceptionType']),
        exceptionNote: asStrOrNull(j['exceptionNote']),
        scans: mapList(j['scans'], RunPickingScan.fromJson),
      );

  final String id;
  final String pickingCode;
  final String allocationRunId;
  final String allocationPlanVersionId;
  final String warehouseId;
  final SheetStatus status;
  final int version;
  final List<RunPickingGather> gathers;
  final String? assignedToUserId;
  final DateTime? issuedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? completedByUserId;
  final String? exceptionType;
  final String? exceptionNote;
  final List<RunPickingScan> scans;

  double get totalRequired =>
      gathers.fold<double>(0, (s, g) => s + g.requiredQuantity);
  double get totalPicked =>
      gathers.fold<double>(0, (s, g) => s + g.pickedQuantity);
  int get doneGathers => gathers.where((g) => g.isDone).length;

  bool get allPicked => gathers.isNotEmpty && doneGathers == gathers.length;
  bool get isClosed =>
      status == SheetStatus.ready || status == SheetStatus.needsHandling;
  bool get hasException => (exceptionType ?? '').isNotEmpty;

  /// Order codes on this sheet, in a stable order, each appearing once.
  ///
  /// This is the bridge from the sheet to the two steps after it: readiness and
  /// issue are decided per order, while the sheet is organised per batch.
  List<String> get orderCodes {
    final seen = <String>{};
    final codes = <String>[];
    for (final gather in gathers) {
      for (final split in gather.splits) {
        if (seen.add(split.orderCode)) codes.add(split.orderCode);
      }
    }
    codes.sort();
    return codes;
  }

  /// The order id behind an order code on this sheet, for the endpoints that
  /// are keyed by id rather than by the code a person reads.
  String? orderIdOf(String orderCode) {
    for (final gather in gathers) {
      for (final split in gather.splits) {
        if (split.orderCode == orderCode) return split.salesOrderId;
      }
    }
    return null;
  }

  /// Every part of one order on this sheet, each with the batch it came from,
  /// for the issue screen - which has to name order, batch and quantity before
  /// anything is confirmed.
  List<RunPickingPart> partsOf(String orderCode) => <RunPickingPart>[
        for (final gather in gathers)
          for (final split in gather.splits)
            if (split.orderCode == orderCode)
              RunPickingPart(gather: gather, split: split),
      ];

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'pickingCode': pickingCode,
        'allocationRunId': allocationRunId,
        'allocationPlanVersionId': allocationPlanVersionId,
        'warehouseId': warehouseId,
        'status': status.code,
        'version': version,
        'gathers': gathers.map((g) => g.toJson()).toList(),
        'assignedToUserId': assignedToUserId,
        'issuedAt': isoOrNull(issuedAt),
        'startedAt': isoOrNull(startedAt),
        'completedAt': isoOrNull(completedAt),
        'completedByUserId': completedByUserId,
        'exceptionType': exceptionType,
        'exceptionNote': exceptionNote,
        'scans': scans.map((s) => s.toJson()).toList(),
      };
}

/// One split together with the gather it belongs to, so a screen that reads by
/// order still knows which batch the cartons come off.
class RunPickingPart {
  const RunPickingPart({required this.gather, required this.split});

  final RunPickingGather gather;
  final RunPickingSplit split;
}

/// How much of a scan goes to one allocation, as the scan endpoint takes it.
class RunPickingSplitQuantity {
  const RunPickingSplitQuantity({
    required this.allocationRunAllocationId,
    required this.quantity,
  });

  final String allocationRunAllocationId;
  final double quantity;
}
