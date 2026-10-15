import 'package:fscm_mobile/data/models/json_utils.dart';

/// In-app notification (server `GET /notifications` or created locally by
/// the sync service, e.g. "order rejected after sync").
class AppNotification {
  const AppNotification({
    required this.id,
    required this.text,
    required this.createdAt,
    this.unread = true,
    this.orderCode = '',
    this.kind = '',
    this.isLocal = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: asStr(j['id']),
        text: asStr(j['text']),
        createdAt: asDate(j['createdAt']) ?? DateTime.now(),
        unread: asBool(j['unread'], true),
        orderCode: asStr(j['orderCode']),
        kind: asStr(j['kind']),
        isLocal: asBool(j['isLocal']),
      );

  final String id;
  final String text;
  final DateTime createdAt;
  final bool unread;

  /// Order (DH-/OFF-) the notification refers to, if any.
  final String orderCode;

  /// `debt`, `picking`, `label`, `order` ... used to pick the deep link.
  final String kind;
  final bool isLocal;

  AppNotification markRead() => AppNotification(
        id: id,
        text: text,
        createdAt: createdAt,
        unread: false,
        orderCode: orderCode,
        kind: kind,
        isLocal: isLocal,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'text': text,
        'createdAt': isoOrNull(createdAt),
        'unread': unread,
        'orderCode': orderCode,
        'kind': kind,
        'isLocal': isLocal,
      };
}
