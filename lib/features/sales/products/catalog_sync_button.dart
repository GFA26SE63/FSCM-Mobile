import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/network_monitor.dart';
import 'package:fscm_mobile/data/remote/sync_api.dart';
import 'package:fscm_mobile/data/repositories/catalog_repository.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';

final _catalogDownloadingProvider = StateProvider<bool>((ref) => false);

class CatalogSyncButton extends ConsumerWidget {
  const CatalogSyncButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(_catalogDownloadingProvider);
    final online = ref.watch(networkMonitorProvider).online;

    return IconButton(
      tooltip: online ? 'Cập nhật catalog' : 'Đang offline',
      onPressed: busy || !online ? null : () => _download(context, ref),
      icon: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.sync),
    );
  }

  Future<void> _download(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final busy = ref.read(_catalogDownloadingProvider.notifier);

    if (busy.state) return;

    // Capture repository của user bắt đầu request.
    final repository = ref.read(catalogRepositoryProvider);
    final api = ref.read(syncApiProvider);

    busy.state = true;

    try {
      final snapshot = await api.snapshot();
      await repository.applySnapshot(snapshot);

      ref.read(dataVersionProvider.notifier).state++;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã cập nhật sản phẩm, giá và khuyến mãi.'),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiException.describe(error)),
          ),
        );
      }
    } finally {
      busy.state = false;
    }
  }
}
