import 'package:flutter_test/flutter_test.dart';

import 'package:fscm_mobile/core/utils/quantity.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/run_picking.dart';

/// The shape `GET /picking-lists/{code}` actually returns, trimmed.
Map<String, dynamic> sheetJson() => <String, dynamic>{
      'id': 'sheet-1',
      'pickingCode': 'PS-20261027-TA-01',
      'allocationRunId': 'run-1',
      'allocationPlanVersionId': 'plan-1',
      'warehouseId': 'wh-ta',
      'assignedToUserId': null,
      'status': 'Picking',
      'version': 3,
      'issuedAt': '2026-10-27T01:32:00Z',
      'startedAt': null,
      'completedAt': null,
      'completedByUserId': null,
      'exceptionType': null,
      'exceptionNote': null,
      'scans': <Map<String, dynamic>>[],
      'gathers': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'gather-1',
          'productId': 'p-1',
          'sku': 'SKU001',
          'batchId': 'b-1',
          'batchCode': 'WH-TA-SKU001-18102026',
          'requiredQuantity': 60,
          'pickedQuantity': 10,
          'remainingQuantity': 50,
          'status': 'Pending',
          'splits': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'split-1',
              'allocationRunAllocationId': 'alloc-1',
              'allocationPlanPriceId': 'price-1',
              'salesOrderId': 'order-24',
              'salesOrderLineId': 'line-1',
              'orderCode': 'DH-001024',
              'requiredQuantity': 40,
              'pickedQuantity': 10,
              'remainingQuantity': 30,
            },
            <String, dynamic>{
              'id': 'split-2',
              'allocationRunAllocationId': 'alloc-2',
              'allocationPlanPriceId': 'price-2',
              'salesOrderId': 'order-21',
              'salesOrderLineId': 'line-2',
              'orderCode': 'DH-001021',
              'requiredQuantity': 20,
              'pickedQuantity': 0,
              'remainingQuantity': 20,
            },
          ],
        },
        <String, dynamic>{
          'id': 'gather-2',
          'productId': 'p-3',
          'sku': 'SKU003',
          'batchId': 'b-3',
          'batchCode': 'WH-TA-SKU003-24102026',
          'requiredQuantity': 20,
          'pickedQuantity': 20,
          'remainingQuantity': 0,
          'status': 'Picked',
          'splits': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'split-3',
              'allocationRunAllocationId': 'alloc-3',
              'allocationPlanPriceId': 'price-3',
              'salesOrderId': 'order-24',
              'salesOrderLineId': 'line-3',
              'orderCode': 'DH-001024',
              'requiredQuantity': 20,
              'pickedQuantity': 20,
              'remainingQuantity': 0,
            },
          ],
        },
      ],
    };

void main() {
  group('RunPickingSheet', () {
    test('parses the sheet as one warehouse share of a whole run', () {
      final sheet = RunPickingSheet.fromJson(sheetJson());

      expect(sheet.pickingCode, 'PS-20261027-TA-01');
      expect(sheet.status, SheetStatus.picking);
      expect(sheet.version, 3);
      expect(sheet.gathers, hasLength(2));
      expect(sheet.totalRequired, 80);
      expect(sheet.totalPicked, 30);
      expect(sheet.doneGathers, 1);
      expect(sheet.allPicked, isFalse);
      expect(sheet.isClosed, isFalse);
    });

    test('carries the price reference on every split', () {
      final sheet = RunPickingSheet.fromJson(sheetJson());

      // Losing this is what makes a split untraceable back to the money the
      // run approved for it, which is why it is asserted rather than assumed.
      for (final gather in sheet.gathers) {
        for (final split in gather.splits) {
          expect(split.allocationPlanPriceId, isNotEmpty);
          expect(split.allocationRunAllocationId, isNotEmpty);
        }
      }
    });

    test('lists each order once even when it draws from several batches', () {
      final sheet = RunPickingSheet.fromJson(sheetJson());

      // DH-001024 appears on both gathers; the issue step is per order, so it
      // must be offered once, not twice.
      expect(sheet.orderCodes, <String>['DH-001021', 'DH-001024']);
    });

    test('maps an order code to the id the shipment endpoints need', () {
      final sheet = RunPickingSheet.fromJson(sheetJson());

      expect(sheet.orderIdOf('DH-001024'), 'order-24');
      expect(sheet.orderIdOf('DH-999999'), isNull);
    });

    test('groups an order parts with the batch each came off', () {
      final sheet = RunPickingSheet.fromJson(sheetJson());

      final parts = sheet.partsOf('DH-001024');
      expect(parts, hasLength(2));
      expect(parts.map((p) => p.gather.batchCode).toSet(), <String>{
        'WH-TA-SKU001-18102026',
        'WH-TA-SKU003-24102026',
      });
      // Not merged into one SKU row: the batch is what the price was decided
      // on, so two batches of one SKU stay two parts.
      expect(parts.map((p) => p.split.requiredQuantity).toList(),
          <double>[40, 20]);
    });

    test('a closed sheet is closed whether or not it went well', () {
      final ready = RunPickingSheet.fromJson(sheetJson()..['status'] = 'Ready');
      final handling =
          RunPickingSheet.fromJson(sheetJson()..['status'] = 'NeedsHandling');

      expect(ready.isClosed, isTrue);
      expect(handling.isClosed, isTrue);
    });
  });

  group('RunPickingGather.apportion', () {
    test('fills the earliest order first when a scan cannot cover everyone',
        () {
      final gather = RunPickingSheet.fromJson(sheetJson()).gathers.first;

      final spread = gather.apportion(35);

      // 30 to the order in front, the remaining 5 to the next. Spreading it
      // evenly would hand an earlier order's cartons to a later one.
      expect(spread.map((s) => s.allocationRunAllocationId).toList(),
          <String>['alloc-1', 'alloc-2']);
      expect(spread.map((s) => s.quantity).toList(), <double>[30, 5]);
    });

    test('never hands out more than a split still owes', () {
      final gather = RunPickingSheet.fromJson(sheetJson()).gathers.first;

      final spread = gather.apportion(500);

      expect(spread.fold<double>(0, (sum, s) => sum + s.quantity), 50);
    });

    test('stops at the quantity scanned', () {
      final gather = RunPickingSheet.fromJson(sheetJson()).gathers.first;

      final spread = gather.apportion(12);

      expect(spread, hasLength(1));
      expect(spread.single.quantity, 12);
    });

    test('a finished gather has nothing to apportion', () {
      final gather = RunPickingSheet.fromJson(sheetJson()).gathers[1];

      expect(gather.isDone, isTrue);
      expect(gather.apportion(5), isEmpty);
    });
  });

  group('Qty', () {
    test('drops trailing zeros without losing real decimals', () {
      expect(Qty.format(12), '12');
      expect(Qty.format(12.5), '12.5');
      expect(Qty.format(12.25), '12.25');
      expect(Qty.cartons(7), '7 thùng');
    });

    test('does not call a gather short over float noise', () {
      // numeric(18,3) arithmetic arrives with this kind of dust on it.
      expect(Qty.covers(9.9999999, 10), isTrue);
      expect(Qty.covers(9.9, 10), isFalse);
    });
  });
}
