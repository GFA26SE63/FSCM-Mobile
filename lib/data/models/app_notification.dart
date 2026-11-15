import 'package:fscm_mobile/data/models/json_utils.dart';

/// In-app notification (server `GET /notifications` or created locally by
/// the sync service, e.g. "order rejected after sync").
class AppNotification {
  const AppNotification({
    required this.id,
    required this.text,
    required this.createdAt,
    this.title = '',
    this.unread = true,
    this.orderCode = '',
    this.kind = '',
    this.deepLink = '',
    this.relatedEntityType = '',
    this.relatedEntityId = '',
    this.isLocal = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    final hasServerReadState = j.containsKey('isRead');
    return AppNotification(
      id: asStr(j['id']),
      title: asStr(j['title']),
      text: asStr(j['message'] ?? j['text']),
      createdAt: asDate(j['createdAt']) ?? DateTime.now(),
      unread:
          hasServerReadState ? !asBool(j['isRead']) : asBool(j['unread'], true),
      orderCode: asStr(j['orderCode']),
      kind: asStr(j['type'] ?? j['kind']),
      deepLink: asStr(j['deepLink']),
      relatedEntityType: asStr(j['relatedEntityType']),
      relatedEntityId: asStr(j['relatedEntityId']),
      isLocal: asBool(j['isLocal']),
    );
  }

  final String id;
  final String title;
  final String text;
  final DateTime createdAt;
  final bool unread;

  /// Order (DH-/OFF-) the notification refers to, if any.
  final String orderCode;

  /// `debt`, `picking`, `label`, `order` ... used to pick the deep link.
  final String kind;
  final String deepLink;
  final String relatedEntityType;
  final String relatedEntityId;
  final bool isLocal;

  AppNotification markRead() => AppNotification(
        id: id,
        title: title,
        text: text,
        createdAt: createdAt,
        unread: false,
        orderCode: orderCode,
        kind: kind,
        deepLink: deepLink,
        relatedEntityType: relatedEntityType,
        relatedEntityId: relatedEntityId,
        isLocal: isLocal,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'text': text,
        'createdAt': isoOrNull(createdAt),
        'unread': unread,
        'orderCode': orderCode,
        'kind': kind,
        'deepLink': deepLink,
        'relatedEntityType': relatedEntityType,
        'relatedEntityId': relatedEntityId,
        'isLocal': isLocal,
      };
}
