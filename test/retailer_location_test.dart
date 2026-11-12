import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/data/models/retailer_declaration.dart';
import 'package:fscm_mobile/data/models/map_place.dart';
import 'package:fscm_mobile/data/remote/vietmap_api.dart';

class _MapAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  Object? data;
  int status = 200;
  DioExceptionType? failure;

  /// Plain-text body without a content type, as VietMap sends for HTTP 423.
  String? rawText;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    if (failure != null) {
      throw DioException(requestOptions: options, type: failure!);
    }
    if (rawText != null) {
      return ResponseBody.fromString(rawText!, status);
    }
    return ResponseBody.fromString(jsonEncode(data), status, headers: {
      Headers.contentTypeHeader: ['application/json']
    });
  }

  @override
  void close({bool force = false}) {}
}

RetailerDeclarationInput _input({double? lat, double? lng, String? placeId}) =>
    RetailerDeclarationInput(
      name: 'Điểm bán An Phú',
      contactName: 'An',
      phone: '0901234567',
      email: 'an@example.com',
      address: 'Địa chỉ đã chọn',
      retailerType: RetailerTypeOption.groceryStore,
      forecastRevenue: 100000,
      storeSizeSquareMeters: 30,
      purchasingCapacity: 10,
      purchaseFrequencyPerMonth: 4,
      requestedCreditTermDays: 0,
      assessmentNote: '',
      mlorDeclarations: [],
      submitForReview: false,
      latitude: lat,
      longitude: lng,
      providerPlaceId: placeId,
    );

void main() {
  test('create and edit serialize selected coordinates and place reference',
      () {
    final input = _input(lat: 10.77, lng: 106.7, placeId: 'ref-1');
    for (final body in [
      input.toJson(regionId: 'r', salesGroupId: 'g'),
      input.toJson()
    ]) {
      expect(body['latitude'], 10.77);
      expect(body['longitude'], 106.7);
      expect(body['providerPlaceId'], 'ref-1');
    }
  });

  test('declaration read preserves coordinates for reopening an edit', () {
    final declaration = RetailerDeclaration.fromJson({
      'id': 'r',
      'latitude': '10.77',
      'longitude': 106.7,
      'providerPlaceId': 'ref-1',
    });
    expect(declaration.latitude, 10.77);
    expect(declaration.longitude, 106.7);
    expect(declaration.providerPlaceId, 'ref-1');
  });

  test('missing coordinates stay unknown, manual pin has no fake place ID', () {
    expect(_input().toJson()['latitude'], isNull);
    expect(_input().toJson()['longitude'], isNull);
    expect(_input(lat: 10.77, lng: 106.7).toJson()['providerPlaceId'], isNull);
    expect(RetailerDeclaration.fromJson({}).latitude, isNull);
    expect(MapPlace.validCoordinates(0, 0), isTrue);
  });

  test('partial and out-of-range coordinates are rejected before submission',
      () {
    expect(() => _input(lat: 10).toJson(), throwsA(isA<ApiException>()));
    expect(
        () => _input(lat: 91, lng: 106).toJson(), throwsA(isA<ApiException>()));
    expect(() => _input(lat: double.nan, lng: 106).toJson(),
        throwsA(isA<ApiException>()));
  });

  test('VietMap searches then resolves selected reference without FSCM auth',
      () async {
    final adapter = _MapAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://maps.vietmap.vn/api/'))
      ..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final api = VietMapApi(dio,
        mapsApiKey: 'test-maps-key', searchApiKey: 'test-client-key');
    adapter.data = [
      {'ref_id': 'ref-1', 'display': 'Địa chỉ kết quả'}
    ];
    final suggestions = await api.search('Địa chỉ');
    expect(suggestions.single.referenceId, 'ref-1');
    expect(adapter.requests.single.path, 'autocomplete/v4');
    adapter.data = {'lat': 10.77, 'lng': 106.7, 'display': 'Địa chỉ chi tiết'};
    final selected = await api.place(suggestions.single);
    expect(selected.latitude, 10.77);
    expect(selected.address, 'Địa chỉ chi tiết');
    expect(selected.providerPlaceId, 'ref-1');
    expect(adapter.requests.last.queryParameters['refid'], 'ref-1');
    expect(
        adapter.requests.every((request) => !request.headers.keys
            .any((key) => key.toLowerCase() == 'authorization')),
        isTrue);
  });

  test(
      'VietMap errors and malformed results never become empty success or zero coordinates',
      () async {
    final adapter = _MapAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://maps.vietmap.vn/api/'))
      ..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final api = VietMapApi(dio,
        mapsApiKey: 'test-maps-key', searchApiKey: 'test-client-key');
    adapter.data = {'unexpected': true};
    await expectLater(api.search('Địa chỉ'), throwsA(isA<ApiException>()));
    adapter.data = {'lat': null, 'lng': 106};
    await expectLater(
        api.place(const MapSuggestion(referenceId: 'ref', display: 'Place')),
        throwsA(isA<ApiException>()));
    adapter.status = 423;
    await expectLater(api.search('Địa chỉ'), throwsA(isA<ApiException>()));
    expect(await api.search('a'), isEmpty);
  });

  test('declaration request keeps the same JSON fields for create and update',
      () {
    const shared = <String>{
      'name',
      'contactName',
      'phone',
      'email',
      'address',
      'retailerType',
      'forecastRevenue',
      'storeSizeSquareMeters',
      'purchasingCapacity',
      'purchaseFrequencyPerMonth',
      'requestedCreditTermDays',
      'assessmentNote',
      'latitude',
      'longitude',
      'providerPlaceId',
      'mlorDeclarations',
      'submitForReview',
    };
    final input = _input(lat: 10.77, lng: 106.7, placeId: 'auto:1');
    expect(input.toJson(regionId: 'r', salesGroupId: 'g').keys.toSet(),
        {...shared, 'regionId', 'salesGroupId'});
    expect(input.toJson().keys.toSet(), shared);
  });

  group('VietMap API', () {
    late _MapAdapter adapter;
    late VietMapApi api;

    setUp(() {
      adapter = _MapAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://maps.vietmap.vn/api/'))
        ..httpClientAdapter = adapter;
      addTearDown(dio.close);
      api = VietMapApi(dio,
          mapsApiKey: 'test-maps-key', searchApiKey: 'test-client-key');
    });

    test('reverse v4 sends the pin and returns the nearest display address',
        () async {
      adapter.data = [
        {
          'lat': 10.759221,
          'lng': 106.675901,
          'ref_id': 'vm:ADDRESS:1',
          'distance': 0,
          'address': 'Phường Chợ Quán,Thành Phố Hồ Chí Minh',
          'name': '197 Trần Phú',
          'display': '197 Trần Phú Phường Chợ Quán,Thành Phố Hồ Chí Minh'
        },
      ];
      expect(await api.reverse(10.759221, 106.675901),
          '197 Trần Phú Phường Chợ Quán,Thành Phố Hồ Chí Minh');
      final request = adapter.requests.single;
      expect(request.path, 'reverse/v4');
      expect(request.queryParameters['lat'], 10.759221);
      expect(request.queryParameters['lng'], 106.675901);
      expect(request.queryParameters['apikey'], 'test-client-key');
      expect(
          request.headers.keys
              .any((key) => key.toLowerCase() == 'authorization'),
          isFalse);
    });

    test(
        'reverse v4 with no usable address is null, malformed body is an error',
        () async {
      adapter.data = [];
      expect(await api.reverse(9, 109.9), isNull);
      adapter.data = [
        {'display': '  '}
      ];
      expect(await api.reverse(9, 109.9), isNull);
      adapter.data = {'unexpected': true};
      await expectLater(api.reverse(9, 109.9), throwsA(isA<ApiException>()));
      await expectLater(
          api.reverse(double.nan, 109.9), throwsA(isA<ApiException>()));
    });

    test('search skips malformed rows but an all-malformed reply is an error',
        () async {
      adapter.data = [
        {'ref_id': 'auto:1', 'display': 'Kết quả 1'},
        {'ref_id': null, 'display': 'Hỏng'},
      ];
      expect(
          (await api.search('Kết quả')).map((s) => s.referenceId), ['auto:1']);
      adapter.data = [
        {'display': 'Hỏng'}
      ];
      await expectLater(api.search('Kết quả'), throwsA(isA<ApiException>()));
      adapter.data = [];
      expect(await api.search('Không có'), isEmpty);
    });

    test('provider failures map to clear messages without leaking the key',
        () async {
      Future<ApiException> failure() async {
        try {
          await api.search('Địa chỉ');
        } on ApiException catch (error) {
          return error;
        }
        fail('expected ApiException');
      }

      adapter.status = 423;
      var error = await failure();
      expect(error.statusCode, 423);
      expect(error.message, contains('chưa được cấp quyền dịch vụ này'));
      adapter.status = 401;
      expect((await failure()).kind, ApiErrorKind.unauthorized);
      adapter.status = 429;
      expect((await failure()).message, contains('quá nhiều yêu cầu'));
      adapter.failure = DioExceptionType.receiveTimeout;
      error = await failure();
      expect(error.kind, ApiErrorKind.timeout);
      adapter.failure = DioExceptionType.connectionError;
      error = await failure();
      expect(error.kind, ApiErrorKind.network);
      expect(error.message, isNot(contains('test-client-key')));
    });

    test(
        'HTTP 423 is an access restriction for every search API, never a parsing failure',
        () async {
      // Real VietMap 423: plain text "Your request is limited", no content type.
      adapter
        ..status = 423
        ..rawText = 'Your request is limited';
      final calls = <Future<Object?> Function()>[
        () => api.search('197 Trần Phú'),
        () =>
            api.place(const MapSuggestion(referenceId: 'auto:1', display: 'x')),
        () => api.reverse(10.759221, 106.675901),
      ];
      for (final call in calls) {
        try {
          await call();
          fail('expected ApiException');
        } on ApiException catch (error) {
          expect(error.statusCode, 423);
          expect(error.message, contains('chưa được cấp quyền dịch vụ này'));
          expect(error.message, isNot(contains('không hợp lệ')));
          expect(error.message, isNot(contains('Dữ liệu vị trí')));
        }
      }
    });

    test('each VietMap service gets its own key', () async {
      adapter.data = [];
      await api.search('Địa chỉ');
      await api.reverse(10.77, 106.7);
      adapter.data = {'lat': 10.77, 'lng': 106.7, 'display': 'Địa chỉ'};
      await api.place(const MapSuggestion(referenceId: 'auto:1', display: 'x'));
      expect(adapter.requests.map((r) => r.path),
          ['autocomplete/v4', 'reverse/v4', 'place/v4']);
      for (final request in adapter.requests) {
        expect(request.queryParameters['apikey'], 'test-client-key');
      }
      expect(api.tileUrlTemplate, contains('apikey=test-maps-key'));
      expect(api.tileUrlTemplate, isNot(contains('test-client-key')));
      expect(api.isMapConfigured, isTrue);
      expect(api.isSearchConfigured, isTrue);
    });

    test('missing search key never calls VietMap and says so in Vietnamese',
        () async {
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final noSearch =
          VietMapApi(dio, mapsApiKey: 'test-maps-key', searchApiKey: '  ');
      expect(noSearch.isSearchConfigured, isFalse);
      expect(noSearch.isMapConfigured, isTrue);
      for (final call in <Future<Object?> Function()>[
        () => noSearch.search('Địa chỉ'),
        () =>
            noSearch.place(const MapSuggestion(referenceId: 'a', display: 'x')),
        () => noSearch.reverse(10, 106),
      ]) {
        await expectLater(
            call(),
            throwsA(isA<ApiException>().having((e) => e.message, 'message',
                contains('Chưa cấu hình dịch vụ tìm địa chỉ'))));
      }
      expect(adapter.requests, isEmpty);
      final noMaps =
          VietMapApi(dio, mapsApiKey: '', searchApiKey: 'test-client-key');
      expect(noMaps.isMapConfigured, isFalse);
      expect(noMaps.isSearchConfigured, isTrue);
    });
  });
}
