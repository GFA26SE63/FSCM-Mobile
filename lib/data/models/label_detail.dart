import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/label_info.dart';

class LabelEvent {
  const LabelEvent({
    required this.id,
    required this.type,
    required this.fromStatus,
    required this.toStatus,
    required this.quantity,
    required this.warehouseCode,
    required this.referenceCode,
    required this.note,
    required this.performedByUserId,
    required this.occurredAt,
  });

  factory LabelEvent.fromJson(Map<String, dynamic> json) {
    return LabelEvent(
      id: asStr(json['id']),
      type: asStr(json['eventType']),
      fromStatus: asStr(json['fromStatus']),
      toStatus: asStr(json['toStatus']),
      quantity: asDouble(json['quantity']),
      warehouseCode: asStr(json['warehouseCode']),
      referenceCode: asStr(json['referenceCode']),
      note: asStr(json['note']),
      performedByUserId: asStr(json['performedByUserId']),
      occurredAt: asDate(json['occurredAt']),
    );
  }

  final String id;
  final String type;
  final String fromStatus;
  final String toStatus;
  final double quantity;
  final String warehouseCode;
  final String referenceCode;
  final String note;
  final String performedByUserId;
  final DateTime? occurredAt;

  String get title {
    const names = <String, String>{
      'Generated': 'Tạo tem',
      'Split': 'Tách tem',
      'Picked': 'Soạn hàng',
      'Inspected': 'Kiểm tra tem',
      'Issued': 'Xuất hàng',
      'Received': 'Nhận hàng',
      'Dispatched': 'Giao vận chuyển',
      'RetailerReceived': 'Retailer nhận hàng',
      'Invalidated': 'Vô hiệu hóa tem',
    };

    return names[type] ?? type;
  }
}

class LabelDetail {
  const LabelDetail({
    required this.label,
    required this.rootCode,
    required this.lineage,
    required this.events,
  });

  factory LabelDetail.fromJson(Map<String, dynamic> json) {
    final labelJson = asMap(json['label']);

    if (asStr(labelJson['qrCode']).isEmpty ||
        json['lineage'] is! List ||
        json['events'] is! List) {
      throw const FormatException(
        'Response tra cứu tem thiếu label, lineage hoặc events.',
      );
    }

    final events = asMapList(json['events']).map(LabelEvent.fromJson).toList()
      ..sort((a, b) {
        final first = a.occurredAt;
        final second = b.occurredAt;

        if (first == null) return second == null ? 0 : -1;
        if (second == null) return 1;

        return first.compareTo(second);
      });

    return LabelDetail(
      label: LabelInfo.fromJson(labelJson),
      rootCode: asStr(labelJson['rootQrCode']),
      lineage: asMapList(json['lineage']).map(LabelInfo.fromJson).toList(),
      events: events,
    );
  }

  final LabelInfo label;
  final String rootCode;
  final List<LabelInfo> lineage;
  final List<LabelEvent> events;

  List<LabelInfo> get children =>
      lineage.where((item) => item.parentCode == label.code).toList();
}
