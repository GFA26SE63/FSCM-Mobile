import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bumped by the sync service whenever local tables or the offline queue
/// changed; repository-backed providers watch it to reload.
final dataVersionProvider = StateProvider<int>((ref) => 0);
