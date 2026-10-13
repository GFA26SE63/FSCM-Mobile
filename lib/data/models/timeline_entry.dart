import 'package:fscm_mobile/data/models/json_utils.dart';

/// One step of a progress / history timeline (order, label, retailer
/// registration). [delta] is an optional quantity change such as `+100`.
class TimelineEntry {
  const TimelineEntry(
      {required this.time, required this.label, this.delta = ''});

  factory TimelineEntry.fromJson(Map<String, dynamic> j) => TimelineEntry(
        time: asDate(j['time']),
        label: asStr(j['label']),
        delta: asStr(j['delta']),
      );

  final DateTime? time;
  final String label;
  final String delta;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'time': isoOrNull(time),
        'label': label,
        'delta': delta,
      };
}
