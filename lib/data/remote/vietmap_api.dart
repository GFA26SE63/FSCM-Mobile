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
  return VietMapApi(dio,
      mapsApiKey: Env.vietMapMapsApiKey, searchApiKey: Env.vietMapSearchApiKey);
});

class VietMapApi {
  VietMapApi(this._dio,
      {required String mapsApiKey, required String searchApiKey})
      : _mapsApiKey = mapsApiKey.trim(),
        _searchApiKey = searchApiKey.trim();

  final Dio _dio;

  /// Tiles only.
  final String _mapsApiKey;

  /// Autocomplete, Place and Reverse only.
  final String _searchApiKey;

  bool get isMapConfigured => _mapsApiKey.isNotEmpty;
  bool get isSearchConfigured => _searchApiKey.isNotEmpty;

  /// Raster base map, authorised by the maps key.
  ///
  /// `tm` is VietMap's street style (roads, street names, places); `st` is
  /// unlabelled satellite imagery. `{r}` becomes `@2x` on high-density screens
  /// (512 px tiles) so labels stay sharp.
  String get tileUrlTemplate =>
      'https://maps.vietmap.vn/maps/tiles/tm/{z}/{x}/{y}{r}.png'
      '?apikey=${Uri.encodeQueryComponent(_mapsApiKey)}';

  /// Search-key request; every caller of this is a search-family API.
  Future<Object?> _get(String path, Map<String, dynamic> query) async {
    if (!isSearchConfigured) {
      throw const ApiException(
          kind: ApiErrorKind.server,
          message: 'Chưa cấu hình dịch vụ tìm địa chỉ của bản đồ. '
              'Vui lòng liên hệ quản trị viên.');
    }
    try {
      return (await _dio.get<Object?>(path, queryParameters: <String, dynamic>{
        'apikey': _searchApiKey,
        ...query
      }))
          .data;
    } on DioException catch (error) {
      // Do not surface request URLs containing the map credential.
      throw _mapError(error);
    }
  }

  static ApiException _mapError(DioException error) {
    final status = error.response?.statusCode;
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
            kind: ApiErrorKind.timeout,
            message: 'Dịch vụ bản đồ phản hồi quá lâu. Vui lòng thử lại.');
      default:
        break;
    }
    if (status == null) {
      return const ApiException(
          kind: ApiErrorKind.network,
          message:
              'Không kết nối được dịch vụ bản đồ. Kiểm tra mạng rồi thử lại.');
    }
    return ApiException(
      kind: switch (status) {
        401 => ApiErrorKind.unauthorized,
        403 => ApiErrorKind.forbidden,
        _ => ApiErrorKind.server,
      },
      statusCode: status,
      message: switch (status) {
        401 ||
        403 =>
          'Khóa tìm địa chỉ của bản đồ không hợp lệ. Vui lòng liên hệ quản trị viên.',
        // VietMap: quota used up, or this API is not enabled for the key.
        // An access restriction, never a parsing failure.
        423 => 'Khóa tìm địa chỉ của bản đồ chưa được cấp quyền dịch vụ này '
            'hoặc đã hết hạn mức. Vui lòng liên hệ quản trị viên.',
        429 =>
          'Đã gửi quá nhiều yêu cầu tới dịch vụ bản đồ. Vui lòng thử lại sau ít phút.',
        _ => 'Không tải được vị trí từ bản đồ. Vui lòng thử lại.',
      },
    );
  }

  /// Autocomplete v4: suggestions carry no coordinates; resolve with [place].
  Future<List<MapSuggestion>> search(String text) async {
    if (text.trim().length < 2) {
      return const [];
    }
    final data = await _get('autocomplete/v4', {'text': text.trim()});
    if (data is! List) {
      throw _invalidResponse();
    }
    final suggestions = <MapSuggestion>[
      for (final item in data)
        if (item is Map &&
            _text(item['ref_id']) != null &&
            _text(item['display']) != null)
          MapSuggestion(
              referenceId: item['ref_id'] as String,
              display: item['display'] as String),
    ];
    // Skip odd rows, but never turn an unreadable response into "no results".
    if (data.isNotEmpty && suggestions.isEmpty) {
      throw _invalidResponse();
    }
    return suggestions;
  }

  Future<MapPlace> place(MapSuggestion suggestion) async {
    final data = await _get('place/v4', {'refid': suggestion.referenceId});
    if (data is! Map) {
      throw _invalidResponse();
    }
    final latitude = _number(data['lat']);
    final longitude = _number(data['lng']);
    if (!MapPlace.validCoordinates(latitude, longitude)) {
      throw _invalidResponse();
    }
    return MapPlace(
        latitude: latitude!,
        longitude: longitude!,
        address: _text(data['display']) ?? suggestion.display,
        providerPlaceId: suggestion.referenceId);
  }

  /// Reverse v4: nearest address for a pin, or null when VietMap has none.
  Future<String?> reverse(double latitude, double longitude) async {
    if (!MapPlace.validCoordinates(latitude, longitude)) {
      throw _invalidResponse();
    }
    final data = await _get('reverse/v4', {'lat': latitude, 'lng': longitude});
    if (data is! List) {
      throw _invalidResponse();
    }
    for (final item in data) {
      final display = item is Map ? _text(item['display']) : null;
      if (display != null) {
        return display;
      }
    }
    return null;
  }

  static String? _text(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  static double? _number(Object? value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');

  ApiException _invalidResponse() => const ApiException(
      kind: ApiErrorKind.server,
      message: 'Dữ liệu vị trí trả về không hợp lệ. Vui lòng thử lại.');
}
