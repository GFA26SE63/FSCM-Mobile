import 'package:flutter/material.dart';

/// Bell icon with unread badge; [count] comes from the caller so this
/// widget stays free of data-layer imports.
class NotificationBell extends StatelessWidget {
  const NotificationBell(
      {super.key, required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Thông báo',
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.notifications_none),
      ),
    );
  }
}
