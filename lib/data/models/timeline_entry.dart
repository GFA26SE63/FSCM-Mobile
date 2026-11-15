import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/enums.dart';

/// One step of a progress / history timeline (order, label, retailer
/// registration). [delta] is an optional quantity change such as `+100`.
class TimelineEntry {
  const TimelineEntry(
      {required this.time, required this.label, this.delta = ''});

  factory TimelineEntry.fromJson(Map<String, dynamic> j) {
    var label = asStr(j['label']);
    if (label.isEmpty) {
      final status = asStr(j['toStatus']);
      final matches = OrderStatus.values.where((value) => value.code == status);
      final statusLabel = matches.isEmpty ? status : matches.first.label;
      final reason = asStr(j['reason']);
      label = reason.isNotEmpty ? reason : statusLabel;
    }
    return TimelineEntry(
        time: asDate(j['time'] ?? j['changedAt']),
        label: label,
        delta: asStr(j['delta']));
  }

  final DateTime? time;
  final String label;
  final String delta;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'time': isoOrNull(time),
        'label': label,
        'delta': delta,
      };
}
