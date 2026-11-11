import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/loyalty.dart';
import 'package:fscm_mobile/data/remote/loyalty_api.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/loyalty_repository.dart';
import 'package:fscm_mobile/features/retailer/loyalty/gifts_screen.dart';
import 'package:fscm_mobile/features/retailer/loyalty/loyalty_screen.dart';
import 'package:fscm_mobile/features/retailer/loyalty/widgets/loyalty_ledger_tile.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'fixtures/loyalty_fixture.dart';

void main() {
  test('card reads exact inactive program and preserves decimal earning rate',
      () async {
    final transport = LoyaltyTransport((request) => ApiResponse(
          statusCode: 200,
          data: request.path == '/loyalty/cards/me'
              ? loyaltyCardFixture()
              : loyaltyProgramFixture(),
        ));
    final client = ApiClient(transport: transport, tokenReader: () => null);
    addTearDown(client.dispose);
    final card = await LoyaltyApi(client).account();
    expect(transport.requests.map((r) => r.path),
        ['/loyalty/cards/me', '/loyalty/programs/program-1']);
    expect(card.program!.isActive, isFalse);
    expect(card.program!.amountPerPoint, 12345.67);
    expect(card.balance, 500);
    expect(card.pending, 100);
    expect(card.held, 50);
    expect(card.expired, 20);
  });

  test('no current program keeps balance and ledger without inventing a rate',
      () async {
    final transport = LoyaltyTransport((_) => ApiResponse(
        statusCode: 200, data: loyaltyCardFixture(programId: null)));
    final client = ApiClient(transport: transport, tokenReader: () => null);
    addTearDown(client.dispose);
    final card = await LoyaltyApi(client).account();
    expect(card.program, isNull);
    expect(card.balance, 500);
    expect(card.ledger, hasLength(1));
    expect(transport.requests, hasLength(1));
  });

  test(
      'missing totals or ledger are errors; empty ledger is a real empty result',
      () {
    for (final field in [
      'availablePoints',
      'pendingPoints',
      'heldPoints',
      'expiredPoints',
      'ledger'
    ]) {
      final data = loyaltyCardFixture()..remove(field);
      expect(() => LoyaltyAccount.fromJson(data), throwsA(isA<ApiException>()));
    }
    expect(LoyaltyAccount.fromJson(loyaltyCardFixture(ledger: [])).ledger,
        isEmpty);
  });

  test(
      'pending cancellation, adjustment, expiry and unknown types stay distinct',
      () {
    final cases = {
      'Earned': PointKind.earned,
      'PendingEarn': PointKind.pending,
      'PendingEarnCancelled': PointKind.pendingCancelled,
      'EarnedAdjusted': PointKind.adjusted,
      'RedemptionHeld': PointKind.held,
      'RedemptionRejected': PointKind.refunded,
      'RedemptionCompleted': PointKind.redeemed,
      'Expired': PointKind.expired,
      'FutureBackendType': PointKind.unknown,
    };
    for (final item in cases.entries) {
      final entry =
          PointLedgerEntry.fromJson(loyaltyLedgerFixture(type: item.key));
      expect(entry.kind, item.value);
      expect(entry.transactionType, item.key);
      expect(entry.description, 'Lý do do máy chủ trả về');
    }
    // The client never compensates for BE pending-total defects by recomputing it.
    final card = LoyaltyAccount.fromJson(loyaltyCardFixture(ledger: [
      loyaltyLedgerFixture(type: 'PendingEarn', points: 100),
      loyaltyLedgerFixture(
          type: 'PendingEarnCancelled', points: -100, id: 'tx-2'),
    ]));
    expect(card.pending, 100);
  });

  test(
      'failed program reads propagate instead of returning a zero earning rate',
      () async {
    final transport = LoyaltyTransport((request) =>
        request.path == '/loyalty/cards/me'
            ? ApiResponse(statusCode: 200, data: loyaltyCardFixture())
            : const ApiResponse(statusCode: 403, data: {'title': 'Forbidden'}));
    final client = ApiClient(transport: transport, tokenReader: () => null);
    addTearDown(client.dispose);
    await expectLater(
        LoyaltyApi(client).account(), throwsA(isA<ApiException>()));
  });

  test('provider blocks Sales and rejects a different retailer card', () async {
    final transport = LoyaltyTransport((_) => ApiResponse(
        statusCode: 200, data: loyaltyCardFixture(programId: null)));
    final client = ApiClient(transport: transport, tokenReader: () => null);
    addTearDown(client.dispose);
    final denied = ProviderContainer(overrides: [
      currentUserProvider.overrideWithValue(const AppUser(
          id: 'sales', fullName: 'Sales', phone: '', role: UserRole.sales)),
      apiClientProvider.overrideWithValue(client),
    ]);
    addTearDown(denied.dispose);
    await expectLater(denied.read(loyaltyAccountProvider.future),
        throwsA(isA<ApiException>()));
    expect(transport.requests, isEmpty);
    final mismatch = ProviderContainer(overrides: [
      currentUserProvider.overrideWithValue(const AppUser(
          id: 'retailer-user',
          fullName: 'Retailer',
          phone: '',
          role: UserRole.retailer,
          retailerCode: 'OTHER')),
      apiClientProvider.overrideWithValue(client),
    ]);
    addTearDown(mismatch.dispose);
    await expectLater(mismatch.read(loyaltyAccountProvider.future),
        throwsA(isA<ApiException>()));
  });

  testWidgets(
      'small screen shows negative balance, all totals and preserves ledger access',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final card = LoyaltyAccount.fromJson(loyaltyCardFixture(
        balance: -50,
        programId: null,
        ledger: [loyaltyLedgerFixture(type: 'EarnedAdjusted', points: -550)]));
    await tester.pumpWidget(ProviderScope(overrides: [
      loyaltyAccountProvider.overrideWith((ref) async => card),
    ], child: const MaterialApp(home: LoyaltyScreen())));
    await tester.pumpAndSettle();
    expect(find.text('-50'), findsOneWidget);
    expect(find.text('Số dư điểm đang âm'), findsOneWidget);
    expect(find.text('Đã hết hạn'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Xem quà & yêu cầu đã gửi'), 180,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Xem quà & yêu cầu đã gửi'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Xem quà & yêu cầu đã gửi'))
            .onPressed,
        isNotNull);
    await tester.scrollUntilVisible(find.text('Điều chỉnh điểm'), 180,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Điều chỉnh điểm'), findsOneWidget);
    expect(find.text('Lý do do máy chủ trả về'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'negative balance blocks new redemption but keeps existing requests visible',
      (tester) async {
    final card = LoyaltyAccount.fromJson(
        loyaltyCardFixture(balance: -1, programId: null));
    await tester.pumpWidget(ProviderScope(
        overrides: [
          loyaltyAccountProvider.overrideWith((ref) async => card),
          giftsProvider.overrideWith((ref) async => [
                const Gift(
                    id: 'gift-1',
                    code: 'QUA-001',
                    name: 'Quà mẫu',
                    points: 100,
                    stock: 20),
              ]),
          redemptionsProvider.overrideWith((ref) async => [
                const GiftRedemption(
                    code: 'redemption-1',
                    giftCode: 'QUA-001',
                    giftName: 'Quà đã yêu cầu',
                    points: 100,
                    status: GiftRequestStatus.requested),
              ]),
        ],
        child: const MaterialApp(
            home: GiftsScreen(redemptionId: 'redemption-1'))));
    await tester.pumpAndSettle();
    expect(find.text('Quà đã yêu cầu'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Thiếu điểm'))
            .onPressed,
        isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'ledger source buttons navigate to the own-order and redemption list routes',
      (tester) async {
    final orderEntry =
        PointLedgerEntry.fromJson(loyaltyLedgerFixture(orderId: 'order-1'));
    final redemptionEntry = PointLedgerEntry.fromJson(loyaltyLedgerFixture(
        id: 'tx-2',
        type: 'RedemptionHeld',
        points: -100,
        redemptionId: 'redemption-1'));
    final router = GoRouter(initialLocation: '/ledger', routes: [
      GoRoute(
          path: '/ledger',
          builder: (context, state) => Scaffold(
                  body: SingleChildScrollView(
                      child: Column(children: [
                LoyaltyLedgerTile(entry: orderEntry),
                LoyaltyLedgerTile(entry: redemptionEntry),
              ])))),
      GoRoute(
          path: AppRoutes.rtOrderDetailPattern,
          builder: (context, state) =>
              Scaffold(body: Text('ORDER ${state.pathParameters['code']}'))),
      GoRoute(
          path: AppRoutes.rtGifts,
          builder: (context, state) => Scaffold(
              body: Text(
                  'REDEMPTION ${state.uri.queryParameters['redemptionId']}'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Xem đơn DH-001'));
    await tester.pumpAndSettle();
    expect(find.text('ORDER order-1'), findsOneWidget);
    router.go('/ledger');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Xem yêu cầu đổi quà'));
    await tester.tap(find.text('Xem yêu cầu đổi quà'));
    await tester.pumpAndSettle();
    expect(find.text('REDEMPTION redemption-1'), findsOneWidget);
  });
}

class LoyaltyTransport implements ApiTransport {
  LoyaltyTransport(this.respond);
  final ApiResponse Function(ApiRequest) respond;
  final requests = <ApiRequest>[];
  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    return respond(request);
  }
}
