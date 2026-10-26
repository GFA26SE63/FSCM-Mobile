import 'package:fscm_mobile/data/mock/mock_store.dart';

/// Run picking sheets and order shipments for the offline demo (F43, F93, F96).
///
/// Shaped as the API's own JSON, so the demo exercises the same parsing as
/// production rather than a convenient second shape.
///
/// The data is arranged to show the two things a per-order picking list could
/// never show. One sheet covers several orders, so a gather is one trip to one
/// batch that splits back to each of them. And one order (DH-001024) is held by
/// a warehouse this keeper cannot see, which is the whole point of F93: the
/// part on their own shelf is picked and still may not leave.
class MockRunPickingSeed {
  MockRunPickingSeed._();

  static const String _runToday = '8f1a0c21-0000-4000-8000-000000000001';
  static const String _planToday = '8f1a0c21-0000-4000-8000-000000000002';
  static const String _runYesterday = '8f1a0c21-0000-4000-8000-000000000003';
  static const String _planYesterday = '8f1a0c21-0000-4000-8000-000000000004';

  static const String whThoiAn = '7a000000-0000-4000-8000-00000000000a';
  static const String whTanChanhHiep = '7a000000-0000-4000-8000-00000000000b';

  static const String _orderTwentyFour = '6b000000-0000-4000-8000-000000001024';
  static const String _orderTwentyOne = '6b000000-0000-4000-8000-000000001021';
  static const String _orderNineteen = '6b000000-0000-4000-8000-000000001019';

  static void apply(MockStore s, DateTime Function(int, int, int) at) {
    // -------------------------------------------------------- today's sheet
    //
    // Two orders, two batches. DH-001024 draws from both batches, DH-001021
    // only from the first - which is exactly the case a per-order sheet hides:
    // the keeper makes one trip to each batch, not one per order.
    s.pickingSheets['PS-20261027-TA-01'] = <String, dynamic>{
      'id': '9c000000-0000-4000-8000-000000000001',
      'pickingCode': 'PS-20261027-TA-01',
      'allocationRunId': _runToday,
      'allocationPlanVersionId': _planToday,
      'warehouseId': whThoiAn,
      'assignedToUserId': null,
      'status': 'Issued',
      'version': 1,
      'issuedAt': at(27, 8, 32).toIso8601String(),
      'startedAt': null,
      'completedAt': null,
      'completedByUserId': null,
      'exceptionType': null,
      'exceptionNote': null,
      'scans': <Map<String, dynamic>>[],
      'gathers': <Map<String, dynamic>>[
        _gather(
          id: '9d000000-0000-4000-8000-000000000001',
          sku: 'SKU001',
          batchCode: 'WH-TA-SKU001-18102026',
          needed: 60,
          picked: 0,
          splits: <Map<String, dynamic>>[
            _split(
              id: '9e000000-0000-4000-8000-000000000001',
              allocationId: '9f000000-0000-4000-8000-000000000001',
              priceId: 'a0000000-0000-4000-8000-000000000001',
              orderId: _orderTwentyFour,
              orderCode: 'DH-001024',
              needed: 40,
              picked: 0,
            ),
            _split(
              id: '9e000000-0000-4000-8000-000000000002',
              allocationId: '9f000000-0000-4000-8000-000000000002',
              priceId: 'a0000000-0000-4000-8000-000000000002',
              orderId: _orderTwentyOne,
              orderCode: 'DH-001021',
              needed: 20,
              picked: 0,
            ),
          ],
        ),
        _gather(
          id: '9d000000-0000-4000-8000-000000000002',
          sku: 'SKU003',
          batchCode: 'WH-TA-SKU003-24102026',
          needed: 20,
          picked: 0,
          splits: <Map<String, dynamic>>[
            _split(
              id: '9e000000-0000-4000-8000-000000000003',
              allocationId: '9f000000-0000-4000-8000-000000000003',
              priceId: 'a0000000-0000-4000-8000-000000000003',
              orderId: _orderTwentyFour,
              orderCode: 'DH-001024',
              needed: 20,
              picked: 0,
            ),
          ],
        ),
      ],
    };

    // ----------------------------------------------------- yesterday's sheet
    s.pickingSheets['PS-20261026-TA-01'] = <String, dynamic>{
      'id': '9c000000-0000-4000-8000-000000000002',
      'pickingCode': 'PS-20261026-TA-01',
      'allocationRunId': _runYesterday,
      'allocationPlanVersionId': _planYesterday,
      'warehouseId': whThoiAn,
      'assignedToUserId': null,
      'status': 'Ready',
      'version': 4,
      'issuedAt': at(26, 13, 10).toIso8601String(),
      'startedAt': at(26, 13, 40).toIso8601String(),
      'completedAt': at(26, 14, 20).toIso8601String(),
      'completedByUserId': null,
      'exceptionType': null,
      'exceptionNote': null,
      'scans': <Map<String, dynamic>>[],
      'gathers': <Map<String, dynamic>>[
        _gather(
          id: '9d000000-0000-4000-8000-000000000003',
          sku: 'SKU003',
          batchCode: 'WH-TA-SKU003-24102026',
          needed: 10,
          picked: 10,
          splits: <Map<String, dynamic>>[
            _split(
              id: '9e000000-0000-4000-8000-000000000004',
              allocationId: '9f000000-0000-4000-8000-000000000004',
              priceId: 'a0000000-0000-4000-8000-000000000004',
              orderId: _orderNineteen,
              orderCode: 'DH-001019',
              needed: 10,
              picked: 10,
            ),
          ],
        ),
      ],
    };

    // ------------------------------------------------------------- shipments
    //
    // DH-001024 is the held case: this warehouse's part is on the sheet, but
    // Kho Tân Chánh Hiệp still owes 10 cartons, so nothing may leave either
    // warehouse.
    //
    // The mock gives that warehouse a WaitingToPick row for simplicity. The
    // real server has no row for it at all until it closes its sheet, and
    // reports it as a part with a null shipment id instead; readiness looks the
    // same from here either way, which is why the screen reads the status and
    // never the id.
    _shipment(
      s,
      id: 'b0000000-0000-4000-8000-000000001024',
      shipmentCode: 'PG-001024-A',
      orderId: _orderTwentyFour,
      orderCode: 'DH-001024',
      warehouseId: whThoiAn,
      warehouseCode: 'WH-TA',
      warehouseName: 'Kho Thới An',
      pickingCode: 'PS-20261027-TA-01',
      status: 'WaitingToPick',
      total: 60,
      lines: <Map<String, dynamic>>[
        _line(1, 'SKU001', 'WH-TA-SKU001-18102026', 40, 182000),
        _line(2, 'SKU003', 'WH-TA-SKU003-24102026', 20, 96000),
      ],
    );
    _shipment(
      s,
      id: 'b0000000-0000-4000-8000-000000001025',
      shipmentCode: 'PG-001024-B',
      orderId: _orderTwentyFour,
      orderCode: 'DH-001024',
      warehouseId: whTanChanhHiep,
      warehouseCode: 'WH-TCH',
      warehouseName: 'Kho Tân Chánh Hiệp',
      pickingCode: 'PS-20261027-TCH-01',
      status: 'WaitingToPick',
      total: 10,
      lines: <Map<String, dynamic>>[
        _line(1, 'SKU001', 'WH-TCH-SKU001-05112026', 10, 182000),
      ],
    );
    _shipment(
      s,
      id: 'b0000000-0000-4000-8000-000000001021',
      shipmentCode: 'PG-001021-A',
      orderId: _orderTwentyOne,
      orderCode: 'DH-001021',
      warehouseId: whThoiAn,
      warehouseCode: 'WH-TA',
      warehouseName: 'Kho Thới An',
      pickingCode: 'PS-20261027-TA-01',
      status: 'WaitingToPick',
      total: 20,
      lines: <Map<String, dynamic>>[
        _line(1, 'SKU001', 'WH-TA-SKU001-18102026', 20, 182000),
      ],
    );

    // DH-001019 came off yesterday's sheet, which closed clean, and draws from
    // this warehouse only - so it is the one order that is actually ready, and
    // the only one the issue button can be demonstrated on.
    _shipment(
      s,
      id: 'b0000000-0000-4000-8000-000000001019',
      shipmentCode: 'PG-001019-A',
      orderId: _orderNineteen,
      orderCode: 'DH-001019',
      warehouseId: whThoiAn,
      warehouseCode: 'WH-TA',
      warehouseName: 'Kho Thới An',
      pickingCode: 'PS-20261026-TA-01',
      status: 'Ready',
      total: 10,
      lines: <Map<String, dynamic>>[
        _line(1, 'SKU003', 'WH-TA-SKU003-24102026', 10, 96000),
      ],
    );
  }

  static Map<String, dynamic> _gather({
    required String id,
    required String sku,
    required String batchCode,
    required double needed,
    required double picked,
    required List<Map<String, dynamic>> splits,
  }) =>
      <String, dynamic>{
        'id': id,
        'productId': 'c0000000-0000-4000-8000-${sku.hashCode.abs()}',
        'sku': sku,
        'batchId': 'd0000000-0000-4000-8000-${batchCode.hashCode.abs()}',
        'batchCode': batchCode,
        'requiredQuantity': needed,
        'pickedQuantity': picked,
        'remainingQuantity': needed - picked,
        'status': picked >= needed ? 'Picked' : 'Pending',
        'splits': splits,
      };

  static Map<String, dynamic> _split({
    required String id,
    required String allocationId,
    required String priceId,
    required String orderId,
    required String orderCode,
    required double needed,
    required double picked,
  }) =>
      <String, dynamic>{
        'id': id,
        'allocationRunAllocationId': allocationId,
        'allocationPlanPriceId': priceId,
        'salesOrderId': orderId,
        'salesOrderLineId': 'e0000000-0000-4000-8000-${id.hashCode.abs()}',
        'orderCode': orderCode,
        'requiredQuantity': needed,
        'pickedQuantity': picked,
        'remainingQuantity': needed - picked,
      };

  static Map<String, dynamic> _line(
          int number, String sku, String batchCode, double qty, double price) =>
      <String, dynamic>{
        'orderLineId':
            'f0000000-0000-4000-8000-${(sku + batchCode).hashCode.abs()}',
        'lineNumber': number,
        'productId': 'c0000000-0000-4000-8000-${sku.hashCode.abs()}',
        'sku': sku,
        'productName': sku,
        'batchId': 'd0000000-0000-4000-8000-${batchCode.hashCode.abs()}',
        'batchCode': batchCode,
        'quantity': qty,
        'unitPrice': price,
        'netAmount': qty * price,
      };

  static void _shipment(
    MockStore s, {
    required String id,
    required String shipmentCode,
    required String orderId,
    required String orderCode,
    required String warehouseId,
    required String warehouseCode,
    required String warehouseName,
    required String pickingCode,
    required String status,
    required double total,
    required List<Map<String, dynamic>> lines,
  }) {
    s.shipments[id] = <String, dynamic>{
      'id': id,
      'orderId': orderId,
      'orderCode': orderCode,
      'warehouseId': warehouseId,
      'warehouseCode': warehouseCode,
      'warehouseName': warehouseName,
      'pickingListId': 'aa000000-0000-4000-8000-${pickingCode.hashCode.abs()}',
      'pickingCode': pickingCode,
      'shipmentCode': shipmentCode,
      'status': status,
      'totalQuantity': total,
      'receivedQuantity': 0,
      'issuedAt': null,
      'exceptionReason': null,
      'version': 1,
      'lines': lines,
    };
  }
}
