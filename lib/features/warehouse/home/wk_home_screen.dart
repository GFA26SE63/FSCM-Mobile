import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/features/common/notifications/notification_bell_button.dart';
import 'package:fscm_mobile/features/warehouse/documents/warehouse_documents_api.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/features/warehouse/documents/warehouse_documents_screen.dart';
import 'package:fscm_mobile/features/warehouse/widgets/wk_widgets.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';

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
          titleSpacing: AppSpacing.lg,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Công việc kho',
                  style: AppText.pageTitle.copyWith(color: AppColors.text)),
              if ((user?.scopeText ?? '').isNotEmpty)
                Text(user!.scopeText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.mutedSmall),
            ],
          ),
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
                final palletCount = arrivals.valueOrNull?.length;
                return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      Text('Xin chào, ${user?.fullName ?? ''}',
                          style:
                              AppText.display.copyWith(color: AppColors.text)),
                      const SizedBox(height: AppSpacing.md),
                      // Activity summary from the data already loaded above.
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                                child: WkStatCard(
                                    label: 'Cần xử lý',
                                    value: '${pending.length}',
                                    color: AppColors.primary)),
                            const SizedBox(width: AppSpacing.s10),
                            Expanded(
                                child: WkStatCard(
                                    label: 'Pallet chờ nhận',
                                    value: palletCount == null
                                        ? '—'
                                        : '$palletCount')),
                            const SizedBox(width: AppSpacing.s10),
                            Expanded(
                                child: WkStatCard(
                                    label: 'Chuyến đang đến',
                                    value: '$incoming',
                                    color: AppColors.info)),
                          ],
                        ),
                      ),
                      const SectionTitle('Chọn nghiệp vụ'),
                      for (final operation in WarehouseOperation.values)
                        WkOperationCard(
                            icon: operation.index < 2
                                ? Icons.move_to_inbox
                                : Icons.outbox,
                            title: operation.title,
                            summary: operation ==
                                    WarehouseOperation.factoryReceipt
                                ? arrivals.isLoading
                                    ? 'Đang tải hàng chờ nhận...'
                                    : arrivals.hasError
                                        ? 'Không tải được hàng chờ nhận — mở để thử lại'
                                        : '${arrivals.valueOrNull?.length ?? 0} pallet chờ nhận'
                                : operation ==
                                        WarehouseOperation.transferReceipt
                                    ? '$incoming chuyến chờ mở PNK · ${pending.where((w) => operation.includes(w.document)).length} phiếu đang xử lý'
                                    : '${pending.where((w) => operation.includes(w.document)).length} yêu cầu / PXK cần xử lý',
                            onTap: () => context
                                .push('/wk/documents/${operation.name}')),
                      const SectionTitle('Chứng từ cần xử lý'),
                      if (pending.isEmpty)
                        const AppCard(
                            child: Text('Không có chứng từ đang chờ xử lý.',
                                style: AppText.muted)),
                      for (final w in pending.take(5))
                        WkDocumentCard(
                            code: asStr(w.document['code']),
                            statusLabel: warehouseStatus(w.document['status']),
                            tone: wkStatusTone(w.document['status']),
                            subtitle: w.document['kind'] == 'Request'
                                ? (w.document['reason'] == 'Transfer'
                                    ? 'Lệnh điều chuyển · Bấm để bắt đầu xuất'
                                    : 'Lệnh xuất đơn · Bấm để bắt đầu xuất')
                                : w.document['kind'] == 'Receipt'
                                    ? (w.document['reason'] == 'Transfer'
                                        ? 'Phiếu nhập luân chuyển đang xử lý'
                                        : 'Phiếu nhập từ nhà máy đang xử lý')
                                    : (w.document['reason'] == 'Transfer'
                                        ? 'Phiếu xuất luân chuyển đang xử lý'
                                        : 'Phiếu xuất bán hàng đang xử lý'),
                            onTap: () => context.push('/wk/document/${w.id}')),
                      const SizedBox(height: AppSpacing.md),
                      // Owner decision pending (Baseline: no QR button on the
                      // Warehouse home): kept exactly as it was.
                      OutlinedButton.icon(
                          onPressed: () =>
                              context.push(AppRoutes.wkLabelLookup),
                          icon: const Icon(Icons.search),
                          label: const Text('Tra cứu QR')),
                      const SizedBox(height: AppSpacing.md),
                      const InfoBanner(
                          text:
                              'Đơn bán hàng và điều chuyển kho do Admin phát hành lệnh trước. Mở lệnh để bắt đầu xuất; chỉ ghi sổ sau khi quét đủ hàng.'),
                    ]);
              })),
    );
  }
}
