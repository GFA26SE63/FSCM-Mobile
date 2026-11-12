import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/data/models/map_place.dart';
import 'package:fscm_mobile/data/models/retailer_declaration.dart';
import 'package:fscm_mobile/data/repositories/map_repository.dart';
import 'package:fscm_mobile/data/repositories/retailer_repository.dart';
import 'package:fscm_mobile/features/sales/declare/declare_retailer_screen.dart';

/// Map service stand-in; these tests never search or tap the map.
class _IdleMapRepository implements MapRepository {
  @override
  bool get isMapConfigured => false;
  @override
  bool get isSearchConfigured => false;
  @override
  String get tileUrlTemplate => '';
  @override
  Future<List<MapSuggestion>> search(String text) => throw UnimplementedError();
  @override
  Future<MapPlace> place(MapSuggestion suggestion) =>
      throw UnimplementedError();
  @override
  Future<String?> reverse(double latitude, double longitude) =>
      throw UnimplementedError();
}

/// Records the update body instead of calling the FSCM API.
class _CapturingRetailerRepository implements RetailerRepository {
  RetailerDeclarationInput? updated;

  @override
  Future<RetailerDeclaration> update(
      String retailerId, RetailerDeclarationInput input) async {
    updated = input;
    return _draft;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _draft = RetailerDeclaration.fromJson(<String, dynamic>{
  'id': 'retailer-1',
  'code': 'RD-1',
  'status': 'Draft',
  'name': 'Tạp hóa An Phú',
  'contactName': 'An',
  'phone': '0901234567',
  'email': 'an@example.com',
  'address': '1 Đường Nguyễn Huệ',
  'latitude': 10.77,
  'longitude': 106.7,
  'providerPlaceId': 'auto:1',
  'storeSizeSquareMeters': 30,
  'forecastRevenue': 1000000,
  'purchasingCapacity': 10,
  'purchaseFrequencyPerMonth': 4,
});

Future<void> _openForm(WidgetTester tester,
    {RetailerRepository? retailers}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(initialLocation: '/declare', routes: [
    GoRoute(
        path: '/',
        builder: (_, __) => const Text('Danh sách khai báo'),
        routes: [
          GoRoute(
              path: 'declare',
              builder: (_, __) => DeclareRetailerScreen(initial: _draft)),
        ]),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      mapRepositoryProvider.overrideWithValue(_IdleMapRepository()),
      salesTerritoriesProvider
          .overrideWith((ref) async => const <SalesTerritory>[]),
      if (retailers != null)
        retailerRepositoryProvider.overrideWithValue(retailers),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

Future<void> _openPicker(WidgetTester tester) async {
  await tester.tap(find.text('Chọn trên bản đồ'));
  await tester.pumpAndSettle();
  expect(find.text('Chọn vị trí điểm bán'), findsOneWidget);
}

Future<void> _saveDraft(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('Lưu nháp'), 300,
      scrollable: find
          .descendant(
              of: find.byType(ListView), matching: find.byType(Scrollable))
          .first);
  await tester.tap(find.text('Lưu nháp'));
  await tester.pumpAndSettle();
}

String _fieldText(WidgetTester tester, String label) => tester
    .widget<TextField>(find.descendant(
        of: find.widgetWithText(TextFormField, label),
        matching: find.byType(TextField)))
    .controller!
    .text;

void main() {
  testWidgets('cancelling the picker leaves the form unchanged',
      (tester) async {
    await _openForm(tester);
    await _openPicker(tester);
    await tester.enterText(find.byType(TextField), 'Bị hủy');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(_fieldText(tester, 'Địa chỉ'), '1 Đường Nguyễn Huệ');
    expect(_fieldText(tester, 'Tên điểm bán'), 'Tạp hóa An Phú');
    expect(find.text('Vị trí đã chọn: 10.770000, 106.700000'), findsOneWidget);
    expect(find.text('Địa chỉ đã đổi, cần xác nhận lại ghim.'), findsNothing);
  });

  testWidgets('reopening the picker shows the saved pin and address',
      (tester) async {
    await _openForm(tester);
    await _openPicker(tester);
    expect(find.text('Tọa độ: 10.770000, 106.700000'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '1 Đường Nguyễn Huệ');
    // The saved address was confirmed with this pin, so no extra check is asked.
    expect(find.byType(CheckboxListTile), findsNothing);
  });

  testWidgets(
      'confirming updates address and coordinates together, keeping other fields',
      (tester) async {
    await _openForm(tester);
    await _openPicker(tester);
    await tester.enterText(find.byType(TextField), '2 Đường Nguyễn Huệ');
    await tester.pump();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('Dùng vị trí này'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn vị trí điểm bán'), findsNothing);
    expect(_fieldText(tester, 'Địa chỉ'), '2 Đường Nguyễn Huệ');
    expect(_fieldText(tester, 'Tên điểm bán'), 'Tạp hóa An Phú');
    expect(find.text('Vị trí đã chọn: 10.770000, 106.700000'), findsOneWidget);
    expect(find.text('Địa chỉ đã đổi, cần xác nhận lại ghim.'), findsNothing);
  });

  testWidgets(
      'editing the address after a pin still asks to confirm the pin again',
      (tester) async {
    await _openForm(tester);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Địa chỉ'), '3 Đường Lê Lợi');
    await tester.pump();
    expect(find.text('Địa chỉ đã đổi, cần xác nhận lại ghim.'), findsOneWidget);
    await _openPicker(tester);
    // The typed address no longer matches the confirmed pin.
    expect(find.byType(CheckboxListTile), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Địa chỉ'), '1 Đường Nguyễn Huệ');
    await tester.pump();
    expect(find.text('Địa chỉ đã đổi, cần xác nhận lại ghim.'), findsNothing);
  });

  testWidgets('place reference survives an address edit that is typed back',
      (tester) async {
    final retailers = _CapturingRetailerRepository();
    await _openForm(tester, retailers: retailers);
    final address = find.widgetWithText(TextFormField, 'Địa chỉ');
    await tester.enterText(address, '1 Đường Nguyễn');
    await tester.pump();
    await tester.enterText(address, '1 Đường Nguyễn Huệ');
    await tester.pump();
    await _saveDraft(tester);
    final body = retailers.updated!.toJson();
    expect(body['address'], '1 Đường Nguyễn Huệ');
    expect(body['latitude'], 10.77);
    expect(body['longitude'], 106.7);
    expect(body['providerPlaceId'], 'auto:1');
    expect(find.text('Danh sách khai báo'), findsOneWidget);
  });

  testWidgets(
      'a manually confirmed address is saved without the old place reference',
      (tester) async {
    final retailers = _CapturingRetailerRepository();
    await _openForm(tester, retailers: retailers);
    await _openPicker(tester);
    await tester.enterText(find.byType(TextField), '2 Đường Nguyễn Huệ');
    await tester.pump();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('Dùng vị trí này'));
    await tester.pumpAndSettle();
    // Choosing a location never submits the declaration by itself.
    expect(retailers.updated, isNull);
    await _saveDraft(tester);
    final body = retailers.updated!.toJson();
    expect(body['address'], '2 Đường Nguyễn Huệ');
    expect(body['latitude'], 10.77);
    expect(body['providerPlaceId'], isNull);
    expect(body['submitForReview'], isFalse);
  });
}
