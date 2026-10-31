import 'package:flutter_test/flutter_test.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/data/mock/mock_api.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/run_picking.dart';
import 'package:fscm_mobile/data/remote/picking_api.dart';
import 'package:fscm_mobile/data/remote/shipments_api.dart';

/// The warehouse end of the chain, driven through the in-process mock backend.
///
/// These go through `ApiClient` and the mock's REST paths rather than calling
/// the models directly, so a route or a field renamed on one side and not the
/// other fails here. That is the failure the mobile app actually had: the
/// screens were sound and every path they posted to returned 404.
void main() {
  late MockApi mock;
  late PickingApi picking;
  late ShipmentsApi shipments;

  /// The warehouse keeper of Kho Thới An, who owns PS-20261027-TA-01. The mock
  /// derives a token from role and id (`MockUser.token`).
  const String keeperToken = 'mock.WarehouseKeeper.U-WK-01';

  setUp(() {
    mock = MockApi();
    final client = ApiClient(transport: mock, tokenReader: () => keeperToken);
    picking = PickingApi(client);
    shipments = ShipmentsApi(client);
  });

  Future<RunPickingSheet> sheet() => picking.get('PS-20261027-TA-01');

  group('F43 sheet', () {
    test('is one warehouse share of a run, covering several orders', () async {
      final s = await sheet();

      expect(s.warehouseId, isNotEmpty);
      expect(s.gathers.length, 2);
      expect(s.orderCodes, <String>['DH-001021', 'DH-001024']);
      expect(s.status, SheetStatus.issued);
    });

    test('the list endpoint answers with the same shape', () async {
      final all = await picking.list();

      expect(all, isNotEmpty);
      expect(all.map((s) => s.pickingCode), contains('PS-20261027-TA-01'));
      // Both the open sheet and yesterday's closed one.
      expect(all.where((s) => s.isClosed), isNotEmpty);
    });
  });

  group('F44 scan, as the sheet depends on it', () {
    test('records cartons against the splits and moves the sheet on', () async {
      final before = await sheet();
      final gather = before.gathers.first;

      final after = await picking.scan(
        before.pickingCode,
        operationKey: 'key-1',
        qrCode: 'TEM-000118',
        expectedPickingVersion: before.version,
        expectedLabelVersion: 0,
        splits: gather.apportion(40),
        quantity: 40,
      );

      expect(after.status, SheetStatus.picking);
      expect(after.version, before.version + 1);
      final touched = after.gathers.firstWhere((g) => g.id == gather.id);
      expect(touched.pickedQuantity, 40);
      // 40 of the 60 gathered: the first order is filled, the second is not.
      expect(touched.splits.first.isDone, isTrue);
      expect(touched.splits.last.pickedQuantity, 0);
    });

    test('the same key twice does not pick twice', () async {
      final before = await sheet();
      final gather = before.gathers.first;
      final splits = gather.apportion(10);

      final first = await picking.scan(before.pickingCode,
          operationKey: 'key-repeat',
          qrCode: 'TEM-000118',
          expectedPickingVersion: before.version,
          expectedLabelVersion: 0,
          splits: splits,
          quantity: 10);
      final second = await picking.scan(before.pickingCode,
          operationKey: 'key-repeat',
          qrCode: 'TEM-000118',
          expectedPickingVersion: first.version,
          expectedLabelVersion: 0,
          splits: splits,
          quantity: 10);

      expect(second.version, first.version);
      expect(second.gathers.first.pickedQuantity,
          first.gathers.first.pickedQuantity);
    });

    test('a label from another batch is refused, not substituted', () async {
      final before = await sheet();
      final gather = before.gathers.first;

      // TEM-000131 is the SKU003 batch; this gather is the SKU001 one.
      await expectLater(
        picking.scan(before.pickingCode,
            operationKey: 'key-wrong-batch',
            qrCode: 'TEM-000131',
            expectedPickingVersion: before.version,
            expectedLabelVersion: 0,
            splits: gather.apportion(5),
            quantity: 5),
        throwsA(anything),
      );
    });
  });

  group('F43 closing the sheet', () {
    test('is refused while a gather is still short', () async {
      final s = await sheet();

      await expectLater(
        picking.complete(s.pickingCode, expectedPickingVersion: s.version),
        throwsA(anything),
      );
    });

    test('an exception closes it as needing handling', () async {
      final s = await sheet();

      final closed = await picking.complete(
        s.pickingCode,
        expectedPickingVersion: s.version,
        exceptionType: 'Shortage',
        note: 'Kệ A-03 thiếu 20 thùng.',
      );

      expect(closed.status, SheetStatus.needsHandling);
      expect(closed.hasException, isTrue);
      expect(closed.isClosed, isTrue);
    });

    test('closing it does not issue anything', () async {
      final s = await sheet();
      await picking.complete(s.pickingCode,
          expectedPickingVersion: s.version,
          exceptionType: 'Shortage',
          note: 'thiếu');

      // Picking finishing is not goods leaving. Nothing on the order may be
      // Issued off the back of this.
      final parts = await shipments.list(orderId: 'order-does-not-exist');
      expect(parts, isEmpty);
      final all = await shipments.list();
      expect(all.where((p) => p.status == ShipmentPartStatus.issued), isEmpty);
    });
  });

  group('F93 readiness', () {
    test('one warehouse still short holds the whole order', () async {
      final s = await sheet();
      final orderId = s.orderIdOf('DH-001024')!;

      final readiness = await shipments.readiness(orderId);

      expect(readiness.isReady, isFalse);
      expect(readiness.blockingReasons, isNotEmpty);
      // The part being held is in a warehouse this keeper never sees, which is
      // the reason the verdict cannot be worked out from the sheet.
      expect(readiness.parts.length, 2);
      expect(readiness.othersThan(s.warehouseId), hasLength(1));
    });

    test('names the warehouse and the reason, not just a refusal', () async {
      final s = await sheet();
      final orderId = s.orderIdOf('DH-001024')!;

      final readiness = await shipments.readiness(orderId);

      expect(readiness.blockingReasons.join(), contains('WH-TCH'));
    });
  });

  group('F96 issue', () {
    test('is refused while the order is not ready', () async {
      final s = await sheet();
      final orderId = s.orderIdOf('DH-001024')!;
      final parts = await shipments.list(orderId: orderId);
      final mine = parts.firstWhere((p) => p.warehouseId == s.warehouseId);

      await expectLater(
        shipments.confirmIssue(mine.id, expectedVersion: mine.version),
        throwsA(anything),
      );
    });

    test('a ready order issues and reports the time back', () async {
      // DH-001019 came off a sheet that closed clean and draws from this
      // warehouse only, so it is the one order that is genuinely ready.
      final parts = await shipments.list();
      final mine = parts.firstWhere((p) => p.orderCode == 'DH-001019');

      final issued =
          await shipments.confirmIssue(mine.id, expectedVersion: mine.version);

      expect(issued.status, ShipmentPartStatus.issued);
      expect(issued.issuedAt, isNotNull);
      expect(issued.hasLeft, isTrue);
    });

    test('confirming twice does not deduct twice', () async {
      final parts = await shipments.list();
      final mine = parts.firstWhere((p) => p.orderCode == 'DH-001019');

      final first =
          await shipments.confirmIssue(mine.id, expectedVersion: mine.version);
      // Deliberately the stale version: a retry of a reply that was lost does
      // not know the server already moved on, and must still be safe.
      final second =
          await shipments.confirmIssue(mine.id, expectedVersion: mine.version);

      expect(second.status, ShipmentPartStatus.issued);
      expect(second.version, first.version);
      expect(second.issuedAt, first.issuedAt);
    });

    test('an exception on the sheet holds every order on it', () async {
      final s = await sheet();
      await picking.complete(s.pickingCode,
          expectedPickingVersion: s.version,
          exceptionType: 'Damaged',
          note: 'Thùng bị ướt.');

      // Both orders on the sheet, not only the one the damage was found on:
      // an order is all or nothing at the door.
      for (final code in <String>['DH-001021', 'DH-001024']) {
        final readiness = await shipments.readiness(s.orderIdOf(code)!);
        expect(readiness.isReady, isFalse, reason: code);
        expect(readiness.hasException, isTrue, reason: code);
      }
    });
  });
}
