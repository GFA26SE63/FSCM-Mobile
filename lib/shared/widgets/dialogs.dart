import 'package:flutter/material.dart';

/// Shows a short toast-like message at the bottom.
void showAppSnack(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            error ? const Color(0xFFB42318) : const Color(0xFF1B1F1D),
        duration: const Duration(seconds: 4),
      ),
    );
}

/// Yes/no confirmation; returns false when dismissed.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Xác nhận',
  String cancelLabel = 'Hủy',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelLabel)),
        FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel)),
      ],
    ),
  );
  return result ?? false;
}
