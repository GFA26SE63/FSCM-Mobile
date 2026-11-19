import 'package:fscm_mobile/data/models/app_notification.dart';

/// One server page of notifications (Backend offset paging, newest first).
class NotificationPage {
  const NotificationPage(
      {required this.items,
      required this.page,
      required this.pageSize,
      required this.totalCount});

  final List<AppNotification> items;
  final int page;
  final int pageSize;
  final int totalCount;

  bool get hasMore => items.isNotEmpty && page * pageSize < totalCount;
}
