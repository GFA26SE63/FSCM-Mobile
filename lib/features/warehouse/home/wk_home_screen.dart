import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/features/common/notifications/notification_bell_button.dart';
import 'package:fscm_mobile/features/warehouse/documents/warehouse_documents_api.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';

class WkHomeScreen extends ConsumerWidget {
  const WkHomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final documents = ref.watch(warehouseDocumentsProvider);
    final arrivals = ref.watch(factoryArrivalsProvider);
    final scope = user?.warehouseIds ?? <String>[];
    return Scaffold(
      appBar: AppBar(
          title: const Text('Công việc kho'),
          actions: const [NotificationBellButton()]),
      body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(warehouseDocumentsProvider);
            ref.invalidate(factoryArrivalsProvider);
            await ref.read(warehouseDocumentsProvider.future);
          },
          child: AsyncBody(
              value: documents,
              onRetry: () => ref.invalidate(warehouseDocumentsProvider),
              builder: (all) {
                final pending = all
                    .where((w) =>
                        w.pending &&
                        scope.contains(w.document['warehouseId']) &&
                        (w.document['kind'] != 'Request' ||
                            !all.any((child) =>
                                child.document['sourceDocumentId'] == w.id)))
                    .toList();
                final incoming = all
                    .where((w) =>
                        w.document['reason'] == 'Transfer' &&
                        w.document['kind'] == 'Issue' &&
                        w.document['status'] == 'Posted' &&
                        scope.contains(w.document['destinationWarehouseId']) &&
                        !all.any((r) => r.document['sourceDocumentId'] == w.id))
                    .length;
                return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text('Xin chào, ${user?.fullName ?? ''}',
                          style: Theme.of(context).textTheme.titleLarge),
                      Text(user?.scopeText ?? ''),
                      const SizedBox(height: 16),
                      const Text('Chọn nghiệp vụ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      for (final operation in WarehouseOperation.values)
                        Card(
                            child: ListTile(
                                leading: Icon(operation.index < 2
                                    ? Icons.move_to_inbox
                                    : Icons.outbox),
                                title: Text(operation.title),
                                subtitle: Text(operation ==
                                        WarehouseOperation.factoryReceipt
                                    ? arrivals.isLoading
                                        ? 'Đang tải hàng chờ nhận...'
                                        : arrivals.hasError
                                            ? 'Không tải được hàng chờ nhận — mở để thử lại'
                                            : '${arrivals.valueOrNull?.length ?? 0} pallet chờ nhận'
                                    : operation ==
                                            WarehouseOperation.transferReceipt
                                        ? '$incoming chuyến chờ mở PNK · ${pending.where((w) => operation.includes(w.document)).length} phiếu đang xử lý'
                                        : '${pending.where((w) => operation.includes(w.document)).length} yêu cầu / PXK cần xử lý'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => context
                                    .push('/wk/documents/${operation.name}'))),
                      const SizedBox(height: 16),
                      const Text('Chứng từ cần xử lý',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      if (pending.isEmpty)
                        const ListTile(
                            title: Text('Không có chứng từ đang chờ xử lý.')),
                      for (final w in pending.take(5))
                        Card(
                            child: ListTile(
                                title: Text(asStr(w.document['code'])),
                                subtitle: Text(w.document['kind'] == 'Request'
                                    ? 'Chờ tạo phiếu xuất kho, sau đó quét QR'
                                    : w.document['kind'] == 'Receipt'
                                        ? 'Phiếu nhập đang xử lý'
                                        : 'Phiếu xuất đang xử lý'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () =>
                                    context.push('/wk/document/${w.id}'))),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                          onPressed: () =>
                              context.push(AppRoutes.wkLabelLookup),
                          icon: const Icon(Icons.search),
                          label: const Text('Tra cứu QR')),
                      const Text(
                          'Đơn bán hàng và kế hoạch luân chuyển phải có yêu cầu xuất trước. Mở yêu cầu để tạo PXK; chỉ xác nhận xuất sau khi quét đủ hàng.'),
                    ]);
              })),
    );
  }
}
