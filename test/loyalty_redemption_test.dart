import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/local/redemption_attempt_store.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/loyalty.dart';
import 'package:fscm_mobile/data/remote/loyalty_api.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/loyalty_repository.dart';
import 'package:fscm_mobile/features/retailer/loyalty/gifts_screen.dart';
import 'package:fscm_mobile/features/retailer/loyalty/widgets/gift_catalog_tile.dart';
import 'package:fscm_mobile/features/retailer/loyalty/widgets/gift_redeem_sheet.dart';
import 'package:fscm_mobile/features/retailer/loyalty/widgets/gift_points_summary.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'fixtures/loyalty_fixture.dart';

const _user = AppUser(
    id: 'user-1',
    fullName: 'Retailer',
    phone: '',
    role: UserRole.retailer,
    retailerCode: '1001');
Map<String, dynamic> _gift({int? stock = 5}) => {
      'id': 'gift-1',
      'code': 'QUA-001',
      'name': 'Quà thử nghiệm',
      'loyaltyProgramId': 'program-1',
      'requiredPoints': 100,
      'availableQuantity': stock,
      'isActive': true,
      'description': 'Mô tả quà',
      'imageUrl': null,
    };
Map<String, dynamic> _request({String key = 'key-1'}) => {
      'id': 'request-1',
      'rewardCode': 'QUA-001',
      'rewardName': 'Quà thử nghiệm',
      'redeemedPoints': 200,
      'status': 'Pending',
      'quantity': 2,
      'quantityIsEstimated': false,
      'clientRequestId': key,
      'createdAt': '2026-11-17T00:00:00Z',
    };
LoyaltyAccount _card() => LoyaltyAccount.fromJson(loyaltyCardFixture(),
    program: LoyaltyProgram.fromJson(
        {...loyaltyProgramFixture(), 'isActive': true}));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
      'stock null stays unlimited; missing stock is an error and image/description survive',
      () {
    final gift = Gift.fromJson(
        {..._gift(stock: null), 'imageUrl': 'https://example.test/gift.png'});
    expect(gift.stock, isNull);
    expect(gift.description, 'Mô tả quà');
    expect(gift.imageUrl, 'https://example.test/gift.png');
    expect(Gift.fromJson(gift.toJson()).stock, isNull);
    expect(() => Gift.fromJson(_gift()..remove('availableQuantity')),
        throwsA(isA<ApiException>()));
    expect(() => Gift.fromJson(_gift(stock: -1)), throwsA(isA<ApiException>()));
    expect(GiftRequestStatus.delivered.label, 'Đã giao quà');
    expect(
        GiftRequestStatus.fromCode('FutureStatus'), GiftRequestStatus.unknown);
  });

  test(
      'catalogue request filters by program and refuses a mismatched server response',
      () async {
    final transport = _Transport((request) {
      expect(request.query, {'programId': 'program-1'});
      return ApiResponse(statusCode: 200, data: [_gift()]);
    });
    final client = ApiClient(transport: transport, tokenReader: () => null);
    addTearDown(client.dispose);
    final gifts = await LoyaltyApi(client).gifts(programId: 'program-1');
    expect(gifts.single.programId, 'program-1');
    final wrong = ApiClient(
        transport: _Transport((_) => ApiResponse(statusCode: 200, data: [
              {..._gift(), 'loyaltyProgramId': 'another-program'}
            ])),
        tokenReader: () => null);
    addTearDown(wrong.dispose);
    await expectLater(LoyaltyApi(wrong).gifts(programId: 'program-1'),
        throwsA(isA<ApiException>()));
  });

  test(
      'retry reuses key and exact body; history preserves quantity and legacy estimate flag',
      () async {
    var first = true;
    final transport = _Transport((request) {
      if (first) {
        first = false;
        throw const ApiException.timeout();
      }
      return ApiResponse(
          statusCode: 200, data: {..._request(), 'quantityIsEstimated': true});
    });
    final client = ApiClient(transport: transport, tokenReader: () => null);
    addTearDown(client.dispose);
    final api = LoyaltyApi(client);
    await expectLater(
        api.redeem(rewardId: 'gift-1', quantity: 2, operationKey: 'key-1'),
        throwsA(isA<ApiException>()));
    final result = await api.redeem(
        rewardId: 'gift-1', quantity: 2, operationKey: 'key-1');
    expect(transport.requests[0].body, transport.requests[1].body);
    expect(transport.requests[0].headers['Idempotency-Key'], 'key-1');
    expect(transport.requests[1].headers['Idempotency-Key'], 'key-1');
    expect(result.quantity, 2);
    expect(result.quantityIsEstimated, isTrue);
  });

  test(
      'attempt survives reopening, scopes server/user, prevents overwrite and ignores late cleanup',
      () async {
    final store = RedemptionAttemptStore(server: 'server-a');
    final attempt = await store.create(
        ownerId: 'user-1',
        retailerId: 'retailer-1',
        gift: Gift.fromJson(_gift()),
        quantity: 2);
    await store.markSent(attempt);
    final reopened = RedemptionAttemptStore(server: 'server-a');
    final saved = (await reopened.read('user-1'))!;
    expect(saved.operationKey, attempt.operationKey);
    expect(saved.quantity, 2);
    expect(saved.mayHaveSucceeded, isTrue);
    expect(await reopened.read('user-2'), isNull);
    expect(await RedemptionAttemptStore(server: 'server-b').read('user-1'),
        isNull);
    await expectLater(
        reopened.create(
            ownerId: 'user-1',
            retailerId: 'retailer-1',
            gift: Gift.fromJson(_gift()),
            quantity: 3),
        throwsA(isA<ApiException>()));
    await reopened.complete('user-1', 'older-key');
    expect(await reopened.read('user-1'), isNotNull);
    await reopened.complete('user-1', attempt.operationKey);
    expect(await reopened.read('user-1'), isNull);
  });

  testWidgets(
      'quantity input updates total, enforces stock, and uses gift units',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: GiftRedeemSheet(
                gift: Gift.fromJson(_gift(stock: 3)), balance: 500))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '2');
    await tester.pump();
    expect(find.text('Tổng điểm: 200'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '4');
    await tester.pump();
    expect(find.text('1–3 quà'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Gửi yêu cầu đổi quà'))
            .onPressed,
        isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'unlimited gift keeps description and compact layout on narrow screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: GiftCatalogTile(
                gift: Gift.fromJson(_gift(stock: null)),
                account: _card(),
                busy: false,
                onRedeem: () {}))));
    expect(find.text('Không giới hạn số lượng'), findsOneWidget);
    expect(find.text('Mô tả quà'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 800.0]) {
    testWidgets('points remain readable without overflow at width $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final account = LoyaltyAccount.fromJson({
        ...loyaltyCardFixture(balance: -12345),
        'heldPoints': 2147483647,
      });
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
        data: MediaQueryData(
            size: Size(width, 850), textScaler: const TextScaler.linear(1.5)),
        child: Scaffold(
            body: ListView(
                padding: const EdgeInsets.all(16),
                children: [GiftPointsSummary(account: account)])),
      )));
      expect(find.text('Điểm khả dụng'), findsOneWidget);
      expect(find.text('Đang giữ đổi quà'), findsOneWidget);
      expect(find.text('-12345'), findsOneWidget);
      expect(find.text('2147483647'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'catalogue failure preserves history, quantity and source highlighting',
      (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      currentUserProvider.overrideWithValue(_user),
      loyaltyAccountProvider.overrideWith((ref) async => _card()),
      pendingRedemptionProvider.overrideWith((ref) async => null),
      giftsProvider
          .overrideWith((ref) async => throw const ApiException.network()),
      redemptionsProvider
          .overrideWith((ref) async => [GiftRedemption.fromJson(_request())]),
    ], child: const MaterialApp(home: GiftsScreen(redemptionId: 'request-1'))));
    await tester.pumpAndSettle();
    final networkBanner = tester
        .widgetList<InfoBanner>(find.byType(InfoBanner))
        .where((banner) => banner.text == const ApiException.network().message);
    expect(networkBanner.single.tone, StatusTone.danger);
    await tester.scrollUntilVisible(find.text('2 quà'), 150,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('2 quà'), findsOneWidget);
    expect(find.text('Tổng 200 điểm'), findsOneWidget);
    expect(
        find.text(
            'Không tìm thấy yêu cầu đổi quà nguồn trong tài khoản hiện tại.'),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final acceptedBeforeTimeout in [true, false]) {
    testWidgets(
        'timeout survives reopening; accepted on server: $acceptedBeforeTimeout',
        (tester) async {
      Map<String, dynamic>? accepted;
      var posts = 0;
      final transport = _Transport((request) {
        if (request.method == 'POST') {
          posts++;
          expect(request.body, {'rewardId': 'gift-1', 'quantity': 2});
          if (posts == 1) {
            if (acceptedBeforeTimeout) {
              accepted = _request(key: request.headers['Idempotency-Key']!);
            }
            throw const ApiException.timeout();
          }
          accepted = _request(key: request.headers['Idempotency-Key']!);
          return ApiResponse(statusCode: 200, data: accepted);
        }
        return ApiResponse(
            statusCode: 200, data: accepted == null ? [] : [accepted]);
      });
      final client = ApiClient(transport: transport, tokenReader: () => null);
      addTearDown(client.dispose);
      Widget app() => ProviderScope(overrides: [
            currentUserProvider.overrideWithValue(_user),
            apiClientProvider.overrideWithValue(client),
            redemptionAttemptStoreProvider
                .overrideWithValue(RedemptionAttemptStore(server: 'test')),
            loyaltyAccountProvider.overrideWith((ref) async => _card()),
            giftsProvider.overrideWith((ref) async => [Gift.fromJson(_gift())]),
          ], child: const MaterialApp(home: GiftsScreen()));
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Đổi'));
      await tester.tap(find.widgetWithText(FilledButton, 'Đổi'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '2');
      await tester.pump();
      await tester.ensureVisible(find.text('Gửi yêu cầu đổi quà'));
      await tester.tap(find.text('Gửi yêu cầu đổi quà'));
      await tester.pumpAndSettle();
      expect(posts, 1);
      final saved = await RedemptionAttemptStore(server: 'test').read('user-1');
      expect(saved!.mayHaveSucceeded, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(posts, 1); // Opening the screen never auto-sends.
      await tester.ensureVisible(find.text('Kiểm tra và thử lại'));
      await tester.tap(find.text('Kiểm tra và thử lại'));
      await tester.pumpAndSettle();
      expect(posts, acceptedBeforeTimeout ? 1 : 2);
      for (final request
          in transport.requests.where((r) => r.method == 'POST')) {
        expect(request.headers['Idempotency-Key'], saved.operationKey);
        expect(request.body, {'rewardId': 'gift-1', 'quantity': 2});
      }
      expect(
          await RedemptionAttemptStore(server: 'test').read('user-1'), isNull);
      expect(tester.takeException(), isNull);
    });
  }
}

class _Transport implements ApiTransport {
  _Transport(this.respond);
  final FutureOr<ApiResponse> Function(ApiRequest) respond;
  final requests = <ApiRequest>[];
  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    return await respond(request);
  }
}
