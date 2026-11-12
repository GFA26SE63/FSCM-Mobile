import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/config/env.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/data/models/map_place.dart';

final vietMapApiProvider = Provider<VietMapApi>((ref) {
  // Separate public service: never send FSCM's bearer token to VietMap.
  final dio = Dio(BaseOptions(
    baseUrl: 'https://maps.vietmap.vn/api/',
    connectTimeout: Env.connectTimeout,
    receiveTimeout: Env.receiveTimeout,
  ));
  ref.onDispose(() => dio.close());
  return VietMapApi(dio, apiKey: Env.vietMapApiKey);
});

class VietMapApi {
  VietMapApi(this._dio, {required String apiKey}) : _apiKey = apiKey.trim();

  final Dio _dio;
  final String _apiKey;

  Future<Object?> _get(String path, Map<String, dynamic> query) async {
    if (_apiKey.isEmpty) {
      throw const ApiException(kind: ApiErrorKind.server,
          message: 'Dịch vụ bản đồ chưa sẵn sàng. Vui lòng thử lại sau.');
    }
    try {
      return (await _dio.get<Object?>(path,
          queryParameters: <String, dynamic>{'apikey': _apiKey, ...query})).data;
    } on DioException catch (error) {
      // Do not surface request URLs containing the map credential.
      throw ApiException(
        kind: error.response == null ? ApiErrorKind.network : ApiErrorKind.server,
        message: error.response?.statusCode == 423
            ? 'Dịch vụ bản đồ hiện không thể nhận thêm yêu cầu. Vui lòng thử lại sau.'
            : 'Không tải được vị trí từ bản đồ. Vui lòng thử lại.',
      );
    }
  }

  Future<List<MapSuggestion>> search(String text) async {
    if (text.trim().length < 2) { return const []; }
    final data = await _get('autocomplete/v4', {'text': text.trim()});
    if (data is! List) { throw _invalidResponse(); }
    return data.map((item) {
      if (item is! Map || item['ref_id'] is! String ||
          (item['ref_id'] as String).trim().isEmpty ||
          item['display'] is! String || (item['display'] as String).trim().isEmpty) {
        throw _invalidResponse();
      }
      return MapSuggestion(referenceId: item['ref_id'] as String,
          display: item['display'] as String);
    }).toList();
  }

  Future<MapPlace> place(MapSuggestion suggestion) async {
    final data = await _get('place/v4', {'refid': suggestion.referenceId});
    if (data is! Map) { throw _invalidResponse(); }
    double? number(Object? value) => value is num
        ? value.toDouble() : double.tryParse(value?.toString() ?? '');
    final latitude = number(data['lat']);
    final longitude = number(data['lng']);
    if (!MapPlace.validCoordinates(latitude, longitude)) { throw _invalidResponse(); }
    return MapPlace(latitude: latitude!, longitude: longitude!,
        address: data['display'] is String && (data['display'] as String).trim().isNotEmpty
            ? data['display'] as String : suggestion.display,
        providerPlaceId: suggestion.referenceId);
  }

  ApiException _invalidResponse() => const ApiException(
      kind: ApiErrorKind.server, message: 'Dữ liệu vị trí trả về không hợp lệ. Vui lòng thử lại.');
}
