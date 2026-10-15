import 'package:fscm_mobile/core/utils/dates.dart';

/// Small, null-tolerant JSON readers shared by all models (no code
/// generation is used in this project).
Map<String, dynamic> asMap(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};

List<Map<String, dynamic>> asMapList(Object? v) => v is List
    ? v
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => e.cast<String, dynamic>())
        .toList()
    : <Map<String, dynamic>>[];

/// Accepts either a bare JSON array or a paged envelope `{items: [...]}`.
List<Map<String, dynamic>> unwrapItems(Object? data) {
  if (data is List) return asMapList(data);
  if (data is Map) return asMapList(data['items']);
  return <Map<String, dynamic>>[];
}

List<T> mapList<T>(Object? v, T Function(Map<String, dynamic>) f) =>
    asMapList(v).map(f).toList();

String asStr(Object? v, [String fallback = '']) =>
    v == null ? fallback : v.toString();

String? asStrOrNull(Object? v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

int asInt(Object? v, [int fallback = 0]) {
  if (v is num) return v.toInt();
  if (v == null) return fallback;
  return int.tryParse(v.toString()) ?? fallback;
}

double asDouble(Object? v, [double fallback = 0]) {
  if (v is num) return v.toDouble();
  if (v == null) return fallback;
  return double.tryParse(v.toString()) ?? fallback;
}

bool asBool(Object? v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v is String) return v.toLowerCase() == 'true';
  if (v is num) return v != 0;
  return fallback;
}

DateTime? asDate(Object? v) => AppDates.tryParse(v);

List<String> asStrList(Object? v) =>
    v is List ? v.map((e) => e.toString()).toList() : <String>[];

String? isoOrNull(DateTime? d) => d == null ? null : AppDates.iso(d);
