import 'package:flutter_test/flutter_test.dart';
import 'package:fmcg/features/warehouse/application/warehouse_controller.dart';
import 'package:fmcg/features/warehouse/domain/warehouse_models.dart';

void main() {
  group('WarehouseController', () {
    test('rejects a source label from the wrong FEFO batch', () {
      final controller = WarehouseController();

      final result = controller.validateSourceLabel(
        pickingId: 'DH-1024A',
        lineIndex: 0,
        labelId: 'TEM-000142',
      );

      expect(result, SourceScanResult.wrongBatch);
      expect(
        controller.pickingById('DH-1024A')!.status,
        PickingStatus.notStarted,
      );
    });

    test('takes a whole label, splits another, then dispatches', () {
      final controller = WarehouseController();

      final whole = controller.confirmPick(
        pickingId: 'DH-1024A',
        lineIndex: 0,
        sourceLabelId: 'TEM-000118',
        quantity: 40,
      );
      final split = controller.confirmPick(
        pickingId: 'DH-1024A',
        lineIndex: 1,
        sourceLabelId: 'TEM-000131',
        quantity: 20,
      );

      expect(whole!.wasSplit, isFalse);
      expect(split!.outputLabelId, 'TEM-000204');
      expect(split.wasSplit, isTrue);
      expect(controller.labelById('TEM-000131')!.quantity, 10);
      expect(controller.pickingById('DH-1024A')!.canDispatch, isTrue);

      expect(controller.dispatch('DH-1024A'), isTrue);
      expect(controller.pickingById('DH-1024A')!.status, PickingStatus.shipped);
      expect(
        controller.labelById('TEM-000204')!.status,
        StockLabelStatus.inTransit,
      );
    });

    test('receives stock and distributes quantity across pallet labels', () {
      final controller = WarehouseController();

      final receipt = controller.receiveStock(
        supplierDocument: 'HD-VNM-092901',
        sku: 'SKU006',
        expiryDate: '19/10/2026',
        quantity: 121,
        labelCount: 2,
        manufacturerLot: 'L2609-006',
      );

      expect(receipt, isNotNull);
      expect(receipt!.batchCode, 'WH-TA-SKU006-19102026');
      expect(receipt.labelIds, hasLength(2));
      final receivedQuantity = receipt.labelIds.fold<int>(
        0,
        (sum, id) => sum + controller.labelById(id)!.quantity,
      );
      expect(receivedQuantity, 121);
      expect(controller.receipts.single.id, 'PN-0927-02');
    });
  });
}
