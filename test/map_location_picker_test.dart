import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/data/models/map_place.dart';
import 'package:fscm_mobile/data/repositories/map_repository.dart';
import 'package:fscm_mobile/shared/widgets/map_location_picker.dart';

const _searchDelay = Duration(milliseconds: 100);
// Longer than the map's double-tap window, so a tap is reported as a tap.
const _tapSettle = Duration(milliseconds: 400);
const _unresolved =
    'Chưa tìm được địa chỉ tại vị trí này. Vui lòng nhập hoặc kiểm tra lại địa chỉ.';

/// Offline tiles: a 1x1 transparent PNG, so tests never touch the network.
class _BlankTileProvider extends TileProvider {
  static final _png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=');

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_png);
}

/// Each call parks on a completer so tests decide when (and in what order) it answers.
class _FakeMapRepository implements MapRepository {
  _FakeMapRepository({this.mapKey = true, this.searchKey = true});

  final bool mapKey;
  final bool searchKey;
  final searches = <String>[];
  final searchReplies = <Completer<List<MapSuggestion>>>[];
  final placeReplies = <Completer<MapPlace>>[];
  final reverseCalls = <(double, double)>[];
  final reverseReplies = <Completer<String?>>[];

  /// What [VietMapApi] throws, without any request, when the search key is missing.
  static const _noSearchKey = ApiException(
      kind: ApiErrorKind.server,
      message: 'Chưa cấu hình dịch vụ tìm địa chỉ của bản đồ. '
          'Vui lòng liên hệ quản trị viên.');

  @override
  bool get isMapConfigured => mapKey;

  @override
  bool get isSearchConfigured => searchKey;

  @override
  String get tileUrlTemplate => 'https://tiles.test/{z}/{x}/{y}.png';

  @override
  Future<List<MapSuggestion>> search(String text) {
    if (!searchKey) return Future.error(_noSearchKey);
    searches.add(text);
    return (searchReplies..add(Completer())).last.future;
  }

  @override
  Future<MapPlace> place(MapSuggestion suggestion) => !searchKey
      ? Future.error(_noSearchKey)
      : (placeReplies..add(Completer())).last.future;

  @override
  Future<String?> reverse(double latitude, double longitude) {
    if (!searchKey) return Future.error(_noSearchKey);
    reverseCalls.add((latitude, longitude));
    return (reverseReplies..add(Completer())).last.future;
  }
}

class _Harness {
  MapPlace? result;
  bool popped = false;
}

Future<_Harness> _open(WidgetTester tester, _FakeMapRepository repo,
    {String address = '', MapPlace? initial}) async {
  final harness = _Harness();
  await tester.pumpWidget(ProviderScope(
    overrides: [mapRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                    body: TextButton(
                  onPressed: () async {
                    harness.result = await Navigator.of(context)
                        .push<MapPlace>(MaterialPageRoute(
                      builder: (_) => MapLocationPicker(
                          address: address,
                          initial: initial,
                          tileProvider: _BlankTileProvider(),
                          searchDelay: _searchDelay),
                    ));
                    harness.popped = true;
                  },
                  child: const Text('Mở bản đồ'),
                )))),
  ));
  await tester.tap(find.text('Mở bản đồ'));
  await tester.pumpAndSettle();
  return harness;
}

Finder get _addressField => find.byType(TextField);

String _addressText(WidgetTester tester) =>
    tester.widget<TextField>(_addressField).controller!.text;

VoidCallback? _confirmButton(WidgetTester tester) => tester
    .widget<FilledButton>(find.widgetWithText(FilledButton, 'Dùng vị trí này'))
    .onPressed;

Future<void> _tapMap(WidgetTester tester, {Offset shift = Offset.zero}) async {
  await tester.tapAt(tester.getCenter(find.byType(FlutterMap)) + shift);
  await tester.pump(_tapSettle);
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_addressField, text);
  await tester.pump();
}

void main() {
  testWidgets('opening picker does not select the default map center',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(
      home: MapLocationPicker(address: 'Địa chỉ nhập tay'),
    )));
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Dùng vị trí này'))
            .onPressed,
        isNull);
    expect(find.textContaining('Tọa độ:'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'reopening and confirming preserves existing coordinates and reference',
      (tester) async {
    MapPlace? result;
    const existing = MapPlace(
        latitude: 10.77,
        longitude: 106.7,
        address: 'Địa chỉ cũ',
        providerPlaceId: 'ref-1');
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
      home: Builder(
          builder: (context) => Scaffold(
                  body: TextButton(
                onPressed: () async {
                  result = await Navigator.of(context)
                      .push<MapPlace>(MaterialPageRoute(
                    builder: (_) => const MapLocationPicker(
                        address: 'Địa chỉ cũ', initial: existing),
                  ));
                },
                child: const Text('Mở bản đồ'),
              ))),
    )));
    await tester.tap(find.text('Mở bản đồ'));
    await tester.pumpAndSettle();
    expect(find.textContaining('10.770000, 106.700000'), findsOneWidget);
    await tester.tap(find.text('Dùng vị trí này'));
    await tester.pumpAndSettle();
    expect(result?.latitude, existing.latitude);
    expect(result?.longitude, existing.longitude);
    expect(result?.providerPlaceId, 'ref-1');
    expect(tester.takeException(), isNull);
  });

  group('address search', () {
    testWidgets('typing is debounced into one search and shows suggestions',
        (tester) async {
      final repo = _FakeMapRepository();
      await _open(tester, repo);
      await _type(tester, 'Ng');
      await _type(tester, 'Nguyễn');
      await _type(tester, 'Nguyễn Huệ');
      expect(repo.searches, isEmpty);
      await tester.pump(_searchDelay);
      expect(repo.searches, ['Nguyễn Huệ']);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      repo.searchReplies.single.complete(const [
        MapSuggestion(
            referenceId: 'auto:1', display: '1 Nguyễn Huệ, Phường Sài Gòn'),
        MapSuggestion(
            referenceId: 'auto:2', display: '2 Nguyễn Huệ, Phường Sài Gòn'),
      ]);
      await tester.pump();
      expect(find.text('1 Nguyễn Huệ, Phường Sài Gòn'), findsOneWidget);
      expect(find.text('2 Nguyễn Huệ, Phường Sài Gòn'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('an older search answering late never replaces newer results',
        (tester) async {
      final repo = _FakeMapRepository();
      await _open(tester, repo);
      await _type(tester, 'Lê Lợi');
      await tester.pump(_searchDelay);
      await _type(tester, 'Lê Lai');
      await tester.pump(_searchDelay);
      expect(repo.searches, ['Lê Lợi', 'Lê Lai']);
      repo.searchReplies[1].complete(
          const [MapSuggestion(referenceId: 'b', display: 'Kết quả Lê Lai')]);
      await tester.pump();
      repo.searchReplies[0].complete(
          const [MapSuggestion(referenceId: 'a', display: 'Kết quả Lê Lợi')]);
      await tester.pump();
      expect(find.text('Kết quả Lê Lai'), findsOneWidget);
      expect(find.text('Kết quả Lê Lợi'), findsNothing);
    });

    testWidgets('no results shows a clear message', (tester) async {
      final repo = _FakeMapRepository();
      await _open(tester, repo);
      await _type(tester, 'xyzxyz');
      await tester.pump(_searchDelay);
      repo.searchReplies.single.complete(const []);
      await tester.pump();
      expect(
          find.text(
              'Không tìm thấy địa chỉ. Thử nhập chi tiết hơn hoặc chọn ghim trên bản đồ.'),
          findsOneWidget);
    });

    testWidgets('search error or timeout is shown, not treated as no results',
        (tester) async {
      final repo = _FakeMapRepository();
      await _open(tester, repo);
      await _type(tester, 'Hai Bà Trưng');
      await tester.pump(_searchDelay);
      repo.searchReplies.single.completeError(const ApiException(
          kind: ApiErrorKind.timeout,
          message: 'Dịch vụ bản đồ phản hồi quá lâu. Vui lòng thử lại.'));
      await tester.pump();
      expect(find.text('Dịch vụ bản đồ phản hồi quá lâu. Vui lòng thử lại.'),
          findsOneWidget);
      expect(find.textContaining('Không tìm thấy địa chỉ'), findsNothing);
    });

    testWidgets('both keys missing disables search and the map',
        (tester) async {
      final repo = _FakeMapRepository(mapKey: false, searchKey: false);
      await _open(tester, repo);
      expect(
          find.text('Chưa cấu hình dịch vụ hiển thị bản đồ. '
              'Vui lòng liên hệ quản trị viên.'),
          findsOneWidget);
      expect(
          find.text('Chưa cấu hình dịch vụ tìm địa chỉ của bản đồ. '
              'Vui lòng liên hệ quản trị viên.'),
          findsOneWidget);
      expect(find.byType(FlutterMap), findsNothing);
      expect(
          tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
          isNull);
      await _type(tester, 'Nguyễn Huệ');
      await tester.pump(_searchDelay);
      expect(repo.searches, isEmpty);
    });

    testWidgets(
        'missing search key keeps the map: tap places a pin, address is typed by hand',
        (tester) async {
      final repo = _FakeMapRepository(searchKey: false);
      final harness = await _open(tester, repo, address: 'Địa chỉ cũ');
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.textContaining('Bạn vẫn có thể chạm bản đồ'), findsOneWidget);
      expect(
          tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
          isNull);
      await _tapMap(tester);
      await tester.pump();
      expect(find.byIcon(Icons.location_pin), findsOneWidget);
      expect(find.textContaining(_unresolved), findsOneWidget);
      await _type(tester, '45 Pasteur, Phường Sài Gòn');
      await tester.pump(_searchDelay);
      expect(repo.searches, isEmpty);
      expect(_confirmButton(tester), isNull);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.text('Dùng vị trí này'));
      await tester.pumpAndSettle();
      expect(harness.result?.address, '45 Pasteur, Phường Sài Gòn');
      expect(harness.result?.latitude, isNotNull);
      expect(harness.result?.providerPlaceId, isNull);
    });

    testWidgets('missing maps key still lets a searched place be chosen',
        (tester) async {
      final repo = _FakeMapRepository(mapKey: false);
      final harness = await _open(tester, repo);
      expect(find.byType(FlutterMap), findsNothing);
      await _type(tester, 'Nguyễn Huệ');
      await tester.pump(_searchDelay);
      repo.searchReplies.single.complete(const [
        MapSuggestion(referenceId: 'auto:1', display: '1 Nguyễn Huệ')
      ]);
      await tester.pump();
      await tester.tap(find.text('1 Nguyễn Huệ'));
      await tester.pump();
      repo.placeReplies.single.complete(const MapPlace(
          latitude: 10.7731,
          longitude: 106.7041,
          address: '1 Đường Nguyễn Huệ',
          providerPlaceId: 'auto:1'));
      await tester.pumpAndSettle();
      // No map controller to move; the choice must still land without errors.
      expect(tester.takeException(), isNull);
      expect(find.text('Tọa độ: 10.773100, 106.704100'), findsOneWidget);
      await tester.tap(find.text('Dùng vị trí này'));
      await tester.pumpAndSettle();
      expect(harness.result?.providerPlaceId, 'auto:1');
    });

    testWidgets('choosing a suggestion moves the marker and fills the address',
        (tester) async {
      final repo = _FakeMapRepository();
      final harness = await _open(tester, repo);
      await _type(tester, 'Nguyễn Huệ');
      await tester.pump(_searchDelay);
      repo.searchReplies.single.complete(const [
        MapSuggestion(referenceId: 'auto:1', display: '1 Nguyễn Huệ'),
      ]);
      await tester.pump();
      await tester.tap(find.text('1 Nguyễn Huệ'));
      await tester.pump();
      expect(find.byIcon(Icons.location_pin), findsNothing);
      repo.placeReplies.single.complete(const MapPlace(
          latitude: 10.7731,
          longitude: 106.7041,
          address: '1 Đường Nguyễn Huệ, Phường Sài Gòn, TP Hồ Chí Minh',
          providerPlaceId: 'auto:1'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.location_pin), findsOneWidget);
      expect(find.text('Tọa độ: 10.773100, 106.704100'), findsOneWidget);
      expect(_addressText(tester),
          '1 Đường Nguyễn Huệ, Phường Sài Gòn, TP Hồ Chí Minh');
      expect(find.text('1 Nguyễn Huệ'), findsNothing);
      await tester.tap(find.text('Dùng vị trí này'));
      await tester.pumpAndSettle();
      expect(harness.result?.latitude, 10.7731);
      expect(harness.result?.longitude, 106.7041);
      expect(harness.result?.address,
          '1 Đường Nguyễn Huệ, Phường Sài Gòn, TP Hồ Chí Minh');
      expect(harness.result?.providerPlaceId, 'auto:1');
    });
  });

  group('reverse geocoding', () {
    testWidgets(
        'tapping the map moves the marker at once, then fills the address',
        (tester) async {
      final repo = _FakeMapRepository();
      final harness = await _open(tester, repo, address: 'Địa chỉ cũ');
      await _tapMap(tester);
      expect(repo.reverseCalls, hasLength(1));
      expect(find.byIcon(Icons.location_pin), findsOneWidget);
      expect(find.text('Đang tìm địa chỉ...'), findsOneWidget);
      expect(_confirmButton(tester), isNull);
      repo.reverseReplies.single
          .complete('12 Lê Lợi, Phường Sài Gòn, TP Hồ Chí Minh');
      await tester.pump();
      expect(find.text('Đang tìm địa chỉ...'), findsNothing);
      expect(_addressText(tester), '12 Lê Lợi, Phường Sài Gòn, TP Hồ Chí Minh');
      expect(_confirmButton(tester), isNotNull);
      await tester.tap(find.text('Dùng vị trí này'));
      await tester.pumpAndSettle();
      final (lat, lng) = repo.reverseCalls.single;
      expect(harness.result?.latitude, lat);
      expect(harness.result?.longitude, lng);
      expect(
          harness.result?.address, '12 Lê Lợi, Phường Sài Gòn, TP Hồ Chí Minh');
      // A tapped pin is not the provider's place, so no place reference is invented.
      expect(harness.result?.providerPlaceId, isNull);
    });

    testWidgets(
        'failed lookup keeps the pin, warns and needs an explicit check',
        (tester) async {
      final repo = _FakeMapRepository();
      final harness = await _open(tester, repo, address: 'Địa chỉ cũ');
      await _tapMap(tester);
      repo.reverseReplies.single.completeError(const ApiException(
          kind: ApiErrorKind.network,
          message: 'Không kết nối được dịch vụ bản đồ.'));
      await tester.pump();
      expect(find.textContaining(_unresolved), findsOneWidget);
      expect(find.byIcon(Icons.location_pin), findsOneWidget);
      expect(find.textContaining('Tọa độ:'), findsOneWidget);
      expect(_confirmButton(tester), isNull);
      await _type(tester, '45 Pasteur, Phường Sài Gòn');
      expect(_confirmButton(tester), isNull);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.text('Dùng vị trí này'));
      await tester.pumpAndSettle();
      expect(harness.result?.address, '45 Pasteur, Phường Sài Gòn');
      expect(harness.result?.latitude, repo.reverseCalls.single.$1);
      expect(harness.result?.providerPlaceId, isNull);
    });

    testWidgets('no address at the pin is reported the same way',
        (tester) async {
      final repo = _FakeMapRepository();
      await _open(tester, repo, address: 'Địa chỉ cũ');
      await _tapMap(tester);
      repo.reverseReplies.single.complete(null);
      await tester.pump();
      expect(find.text(_unresolved), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsOneWidget);
      expect(_confirmButton(tester), isNull);
    });

    testWidgets('address of pin A arriving after pin B never overwrites B',
        (tester) async {
      final repo = _FakeMapRepository();
      final harness = await _open(tester, repo);
      await _tapMap(tester);
      await _tapMap(tester, shift: const Offset(80, 40));
      expect(repo.reverseCalls, hasLength(2));
      expect(repo.reverseCalls[0], isNot(repo.reverseCalls[1]));
      repo.reverseReplies[1].complete('Địa chỉ B');
      await tester.pump();
      repo.reverseReplies[0].complete('Địa chỉ A');
      await tester.pump();
      expect(_addressText(tester), 'Địa chỉ B');
      await tester.tap(find.text('Dùng vị trí này'));
      await tester.pumpAndSettle();
      expect(harness.result?.address, 'Địa chỉ B');
      expect(harness.result?.latitude, repo.reverseCalls[1].$1);
      expect(harness.result?.longitude, repo.reverseCalls[1].$2);
    });

    testWidgets('typing while the address is resolving is never overwritten',
        (tester) async {
      final repo = _FakeMapRepository();
      await _open(tester, repo);
      await _tapMap(tester);
      await _type(tester, 'Tự nhập 99 Hàm Nghi');
      repo.reverseReplies.single.complete('Địa chỉ từ bản đồ');
      await tester.pump();
      expect(_addressText(tester), 'Tự nhập 99 Hàm Nghi');
      expect(find.text('Đang tìm địa chỉ...'), findsNothing);
      expect(find.byType(CheckboxListTile), findsOneWidget);
    });

    testWidgets('a chosen suggestion is not overwritten by an older pin lookup',
        (tester) async {
      final repo = _FakeMapRepository();
      await _open(tester, repo);
      await _tapMap(tester);
      await _type(tester, 'Nguyễn Huệ');
      await tester.pump(_searchDelay);
      repo.searchReplies.single.complete(const [
        MapSuggestion(referenceId: 'auto:1', display: '1 Nguyễn Huệ')
      ]);
      await tester.pump();
      await tester.tap(find.text('1 Nguyễn Huệ'));
      await tester.pump();
      repo.placeReplies.single.complete(const MapPlace(
          latitude: 10.7731,
          longitude: 106.7041,
          address: '1 Đường Nguyễn Huệ',
          providerPlaceId: 'auto:1'));
      await tester.pumpAndSettle();
      repo.reverseReplies.single.complete('Địa chỉ ghim cũ');
      await tester.pumpAndSettle();
      expect(_addressText(tester), '1 Đường Nguyễn Huệ');
      expect(find.text('Tọa độ: 10.773100, 106.704100'), findsOneWidget);
    });

    testWidgets('leaving the picker before the lookup answers is safe',
        (tester) async {
      final repo = _FakeMapRepository();
      final harness = await _open(tester, repo);
      await _tapMap(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(harness.popped, isTrue);
      expect(harness.result, isNull);
      repo.reverseReplies.single.complete('Địa chỉ muộn');
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
