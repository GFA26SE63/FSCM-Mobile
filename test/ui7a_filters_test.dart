import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/app/theme.dart';
import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/utils/clock.dart';
import 'package:fscm_mobile/data/models/complaint.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/loyalty.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/loyalty_repository.dart';
import 'package:fscm_mobile/data/remote/notifications_api.dart';
import 'package:fscm_mobile/data/remote/orders_api.dart';
import 'package:fscm_mobile/data/repositories/sales_orders_controller.dart';
import 'package:fscm_mobile/features/retailer/complaints/complaints_screen.dart';
import 'package:fscm_mobile/features/retailer/loyalty/gifts_screen.dart';
import 'fixtures/loyalty_fixture.dart';
import 'package:fscm_mobile/features/retailer/loyalty/loyalty_screen.dart';
import 'package:fscm_mobile/features/retailer/loyalty/widgets/loyalty_ledger_tile.dart';

/// UI.7A: Loyalty point-history filters and Requests (complaints) filters.
const _user = AppUser(
    id: 'user-1',
    fullName: 'Retailer',
    phone: '',
    role: UserRole.retailer,
    retailerCode: '1001');

void _phone(WidgetTester tester, double width, {double height = 720}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _host(Widget home, List<Override> overrides, double scale) =>
    ProviderScope(
      overrides: [currentUserProvider.overrideWithValue(_user), ...overrides],
      child: MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(body: home),
      ),
    );

PointLedgerEntry _entry(int i, PointKind kind, {int daysAgo = 0}) =>
    PointLedgerEntry(
      id: 'e$i',
      date: AppClock.now().subtract(Duration(days: daysAgo)),
      description: 'Giao dịch số $i',
      points: kind == PointKind.redeemed ? -10 : 10,
      kind: kind,
      transactionType: kind.code,
      balanceAfter: 100,
    );

Complaint _complaint(String id, String status) =>
    Complaint.fromJson(<String, dynamic>{
      'id': id,
      'code': 'YC-$id',
      'status': status,
      'reviewStatus': 'Submitted',
      'requestType': 'Complaint',
      'orderCode': 'DH-001057',
      'sku': 'SKU001',
      'productName': 'Sữa tươi',
      'requestedQuantity': 1,
    });

Future<void> _chip(WidgetTester tester, String label) async {
  final f = find.text(label).first;
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

GiftRedemption _redemption(String id, String status) =>
    GiftRedemption.fromJson(<String, dynamic>{
      'id': id,
      'rewardCode': 'QUA-001',
      'rewardName': 'Quà số $id',
      'redeemedPoints': 100,
      'status': status,
      'createdAt': '2026-11-10T00:00:00Z',
      'quantity': 1,
      'quantityIsEstimated': false,
      'clientRequestId': 'key-$id',
    });

void main() {
  test('user-visible lists default to 10 per page', () {
    expect(OrdersApi.defaultPageSize, 10);
    expect(salesOrdersPageSize, 10);
    expect(NotificationsApi.pageSize, 10);
    expect(ledgerPageSize, 10);
  });

  for (final width in <double>[360, 390]) {
    for (final scale in <double>[1.0, 1.6]) {
      final tag = '${width.toInt()}dp x$scale';

      testWidgets('loyalty history: type + period filters, 10 per step ($tag)',
          (tester) async {
        _phone(tester, width);
        final ledger = <PointLedgerEntry>[
          for (var i = 0; i < 12; i++) _entry(i, PointKind.earned),
          _entry(100, PointKind.redeemed),
          _entry(101, PointKind.pending),
          _entry(102, PointKind.expired, daysAgo: 60),
        ];
        await tester.pumpWidget(_host(
            SingleChildScrollView(child: LoyaltyLedgerSection(ledger: ledger)),
            [],
            scale));
        await tester.pumpAndSettle();

        // 15 rows, 10 visible at first, then the next step.
        expect(find.byType(LoyaltyLedgerTile), findsNWidgets(10));
        await tester.ensureVisible(find.textContaining('Xem thêm'));
        await tester.tap(find.textContaining('Xem thêm'));
        await tester.pumpAndSettle();
        expect(find.byType(LoyaltyLedgerTile), findsNWidgets(15));

        // Type filter reads the real kind; selecting resets the visible step.
        await _chip(tester, 'Chờ cộng');
        expect(find.byType(LoyaltyLedgerTile), findsOneWidget);
        expect(find.text('Giao dịch số 101'), findsOneWidget);

        // Period filter excludes the 60-day-old expiry.
        await _chip(tester, 'Khác');
        expect(find.byType(LoyaltyLedgerTile), findsOneWidget);
        await _chip(tester, '30 ngày');
        expect(find.byType(LoyaltyLedgerTile), findsNothing);
        expect(find.text('Không có giao dịch phù hợp bộ lọc.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('requests: status groups filter the full list ($tag)',
          (tester) async {
        _phone(tester, width, height: 3000);
        await tester.pumpWidget(_host(
            const ComplaintsScreen(),
            [
              complaintsProvider.overrideWith((ref) async => [
                    _complaint('a', 'Open'),
                    _complaint('b', 'Approved'),
                    _complaint('c', 'Rejected'),
                    _complaint('d', 'Cancelled'),
                  ]),
              complaintEvidenceProvider('a')
                  .overrideWith((ref) async => const <ComplaintEvidence>[]),
            ],
            scale));
        await tester.pumpAndSettle();
        expect(
            find.textContaining('YC-', skipOffstage: false), findsNWidgets(4));

        await _chip(tester, 'Từ chối / Hủy');
        expect(
            find.textContaining('YC-', skipOffstage: false), findsNWidgets(2));
        expect(find.text('YC-a'), findsNothing);

        await _chip(tester, 'Đang xử lý');
        expect(find.text('Không có yêu cầu phù hợp bộ lọc.'), findsOneWidget);

        await _chip(tester, 'Tất cả');
        expect(
            find.textContaining('YC-', skipOffstage: false), findsNWidgets(4));
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'gift redemption requests: status chips filter the list ($tag)',
          (tester) async {
        _phone(tester, width, height: 4000);
        final card = LoyaltyAccount.fromJson(loyaltyCardFixture(balance: 150),
            program: LoyaltyProgram.fromJson(
                {...loyaltyProgramFixture(), 'isActive': true}));
        await tester.pumpWidget(_host(
            const GiftsScreen(),
            [
              loyaltyAccountProvider.overrideWith((ref) async => card),
              giftsProvider.overrideWith((ref) async => const <Gift>[]),
              redemptionsProvider.overrideWith((ref) async => [
                    _redemption('r1', 'Pending'),
                    _redemption('r2', 'Approved'),
                    _redemption('r3', 'Rejected'),
                  ]),
              pendingRedemptionProvider.overrideWith((ref) async => null),
            ],
            scale));
        await tester.pumpAndSettle();
        Finder rows() => find.textContaining('Quà số', skipOffstage: false);
        expect(rows(), findsNWidgets(3));

        await _chip(tester, 'Bị từ chối');
        expect(rows(), findsOneWidget);
        expect(find.text('Quà số r3', skipOffstage: false), findsOneWidget);

        await _chip(tester, 'Hoàn tất');
        expect(rows(), findsNothing);
        expect(
            find.text('Không có yêu cầu phù hợp bộ lọc.', skipOffstage: false),
            findsOneWidget);

        await _chip(tester, 'Tất cả');
        expect(rows(), findsNWidgets(3));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
