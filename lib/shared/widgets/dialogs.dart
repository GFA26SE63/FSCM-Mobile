import 'package:flutter/material.dart';
import 'package:fscm_mobile/app/app.dart';

/// Shows a short toast-like message at the bottom.
void showAppSnack(BuildContext context, String message, {bool error = false}) {
  showRootStatus(message, error: error);
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
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: <Widget>[
        SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(confirmLabel),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(cancelLabel),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}
