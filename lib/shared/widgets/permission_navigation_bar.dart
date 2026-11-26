import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fscm_mobile/core/auth/screen_permissions.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';

/// Filters destinations while retaining the router's original branch indexes.
class PermissionNavigationBar extends ConsumerWidget {
  const PermissionNavigationBar(
      {super.key,
      required this.paths,
      required this.destinations,
      required this.selectedIndex,
      required this.onDestinationSelected});
  final List<String> paths;
  final List<Widget> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final indexes = <int>[
      for (var i = 0; i < paths.length; i++)
        if (canAccessMobilePath(user, paths[i])) i
    ];
    if (indexes.length < 2) return const SizedBox.shrink();
    final selected = indexes.indexOf(selectedIndex);
    return NavigationBar(
      selectedIndex: selected < 0 ? 0 : selected,
      onDestinationSelected: (index) => onDestinationSelected(indexes[index]),
      destinations: [for (final index in indexes) destinations[index]],
    );
  }
}
