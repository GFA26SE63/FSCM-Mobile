import 'package:flutter_test/flutter_test.dart';
import 'package:fmcg/features/retailer/application/retailer_controller.dart';
import 'package:fmcg/features/retailer/domain/retailer_models.dart';
import 'package:fmcg/shared/domain/fscm_models.dart';

void main() {
  group('RetailerController', () {
    test('reconciles every label and completes COD receipt', () {
      final controller = RetailerController();
      final order = controller.orderById('DH-1021')!;
      final startingPoints = controller.loyaltyPoints;

      expect(
        controller.scanLabel(order, 'TEM-OTHER-001'),
        LabelScanResult.wrongRetailer,
      );
      expect(controller.scannedFor(order.id), isEmpty);

      for (final batch in controller.labelsFor(order)) {
        expect(
          controller.scanLabel(order, batch.labelCode!),
          LabelScanResult.matched,
        );
      }

      expect(controller.allLabelsScanned(order), isTrue);
      controller.confirmReceipt(order);

      final completed = controller.orderById(order.id)!;
      expect(completed.status, SalesOrderStatus.delivered);
      expect(completed.payment.isPaid, isTrue);
      expect(controller.loyaltyPoints, greaterThan(startingPoints));
    });

    test('records an evidence-backed complaint without changing inventory', () {
      final controller = RetailerController();
      const complaint = RetailerComplaint(
        orderId: 'DH-1021',
        batchCode: 'WH-TA-SKU001-18102026',
        expectedQuantity: 40,
        actualQuantity: 35,
        note: 'Thiếu 5 thùng',
        evidenceCount: 2,
      );

      controller.submitComplaint(complaint);

      expect(controller.complaints.single, same(complaint));
      expect(
        controller.orderById('DH-1021')!.status,
        SalesOrderStatus.delivering,
      );
    });
  });
}
