import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';

/// Renders [child] only if the authenticated user has one of [allowedRoles].
/// Otherwise renders [fallback] (defaults to `SizedBox.shrink()`).
class Authorize extends ConsumerWidget {
  const Authorize({
    super.key,
    required this.allowedRoles,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  final List<UserRole> allowedRoles;
  final Widget child;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentUserProvider)?.role;
    if (role != null && allowedRoles.contains(role)) {
      return child;
    }
    return fallback;
  }
}

