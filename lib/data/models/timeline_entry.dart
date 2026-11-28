import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/enums.dart';

/// One step of a progress / history timeline (order, label, retailer
/// registration). [delta] is an optional quantity change such as `+100`.
class TimelineEntry {
  const TimelineEntry(
      {required this.time,
      required this.label,
      this.delta = '',
      this.statusCode = ''});

  factory TimelineEntry.fromJson(Map<String, dynamic> j) {
    var label = asStr(j['label']);
    final status = asStr(j['toStatus'] ?? j['statusCode']);
    if (label.isEmpty) {
      final matches = OrderStatus.values.where((value) => value.code == status);
      final statusLabel = matches.isEmpty ? status : matches.first.label;
      final reason = asStr(j['reason']);
      label = reason.isNotEmpty ? reason : statusLabel;
    }
    return TimelineEntry(
        time: asDate(j['time'] ?? j['changedAt']),
        label: label,
        delta: asStr(j['delta']),
        statusCode: status);
  }

  final DateTime? time;
  final String label;
  final String delta;

  /// Order status the step moved to (backend code); empty for other timelines.
  final String statusCode;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'time': isoOrNull(time),
        'label': label,
        'delta': delta,
        if (statusCode.isNotEmpty) 'statusCode': statusCode,
      };
}

/// Order history as the RETAILER sees it: each status step shows its
/// [OrderStatus.retailerLabel], and consecutive steps of the same stage
/// (e.g. ConvertedToPo → Picking → Issued, all "Đã xác nhận báo giá") are
/// shown once, at the time the stage was reached. Steps without a status code
/// keep their own label.
List<TimelineEntry> retailerOrderTimeline(List<TimelineEntry> entries) {
  final result = <TimelineEntry>[];
  for (final entry in entries) {
    final known = OrderStatus.values.where((s) => s.code == entry.statusCode);
    final label = known.isEmpty ? entry.label : known.first.retailerLabel;
    if (result.isNotEmpty && result.last.label == label) continue;
    result.add(TimelineEntry(
        time: entry.time,
        label: label,
        delta: entry.delta,
        statusCode: entry.statusCode));
  }
  return result;
}
