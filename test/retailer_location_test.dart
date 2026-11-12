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

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(jsonEncode(data), status,
        headers: {Headers.contentTypeHeader: ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

RetailerDeclarationInput _input({double? lat, double? lng, String? placeId}) =>
    RetailerDeclarationInput(
      name: 'Điểm bán An Phú', contactName: 'An', phone: '0901234567',
      email: 'an@example.com', address: 'Địa chỉ đã chọn',
      retailerType: RetailerTypeOption.groceryStore,
      forecastRevenue: 100000, storeSizeSquareMeters: 30,
      purchasingCapacity: 10, purchaseFrequencyPerMonth: 4,
      requestedCreditTermDays: 0, assessmentNote: '', mlorDeclarations: [],
      submitForReview: false, latitude: lat, longitude: lng, providerPlaceId: placeId,
    );

void main() {
  test('create and edit serialize selected coordinates and place reference', () {
    final input = _input(lat: 10.77, lng: 106.7, placeId: 'ref-1');
    for (final body in [input.toJson(regionId: 'r', salesGroupId: 'g'), input.toJson()]) {
      expect(body['latitude'], 10.77);
      expect(body['longitude'], 106.7);
      expect(body['providerPlaceId'], 'ref-1');
    }
  });

  test('declaration read preserves coordinates for reopening an edit', () {
    final declaration = RetailerDeclaration.fromJson({
      'id': 'r', 'latitude': '10.77', 'longitude': 106.7,
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

  test('partial and out-of-range coordinates are rejected before submission', () {
    expect(() => _input(lat: 10).toJson(), throwsA(isA<ApiException>()));
    expect(() => _input(lat: 91, lng: 106).toJson(), throwsA(isA<ApiException>()));
    expect(() => _input(lat: double.nan, lng: 106).toJson(), throwsA(isA<ApiException>()));
  });

  test('VietMap searches then resolves selected reference without FSCM auth', () async {
    final adapter = _MapAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://maps.vietmap.vn/api/'))
      ..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final api = VietMapApi(dio, apiKey: 'test-client-key');
    adapter.data = [{'ref_id': 'ref-1', 'display': 'Địa chỉ kết quả'}];
    final suggestions = await api.search('Địa chỉ');
    expect(suggestions.single.referenceId, 'ref-1');
    expect(adapter.requests.single.path, 'autocomplete/v4');
    adapter.data = {'lat': 10.77, 'lng': 106.7, 'display': 'Địa chỉ chi tiết'};
    final selected = await api.place(suggestions.single);
    expect(selected.latitude, 10.77);
    expect(selected.address, 'Địa chỉ chi tiết');
    expect(selected.providerPlaceId, 'ref-1');
    expect(adapter.requests.last.queryParameters['refid'], 'ref-1');
    expect(adapter.requests.every((request) =>
        !request.headers.keys.any((key) => key.toLowerCase() == 'authorization')), isTrue);
  });

  test('VietMap errors and malformed results never become empty success or zero coordinates', () async {
    final adapter = _MapAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://maps.vietmap.vn/api/'))
      ..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final api = VietMapApi(dio, apiKey: 'test-client-key');
    adapter.data = {'unexpected': true};
    await expectLater(api.search('Địa chỉ'), throwsA(isA<ApiException>()));
    adapter.data = {'lat': null, 'lng': 106};
    await expectLater(api.place(const MapSuggestion(referenceId: 'ref', display: 'Place')),
        throwsA(isA<ApiException>()));
    adapter.status = 423;
    await expectLater(api.search('Địa chỉ'), throwsA(isA<ApiException>()));
    expect(await api.search('a'), isEmpty);
  });
}
