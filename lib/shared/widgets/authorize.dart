import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/data/repositories/auth_repository.dart';

/// Renders [child] only if the authenticated user has [permission].
/// Otherwise renders [fallback] (defaults to `SizedBox.shrink()`).
class Authorize extends ConsumerWidget {
  const Authorize({
    super.key,
    required this.permission,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  final String permission;
  final Widget child;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user?.hasPermission(permission) == true) {
      return child;
    }
    return fallback;
  }
}
