import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:flutter/material.dart';
import 'package:fscm_mobile/core/utils/focus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/network/network_monitor.dart';
import 'package:fscm_mobile/data/repositories/catalog_repository.dart';
import 'package:fscm_mobile/features/sales/products/catalog_sync_button.dart';
import 'package:fscm_mobile/features/sales/retailers/widgets/retailer_summary_card.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/empty_state.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';

class RetailerListScreen extends ConsumerStatefulWidget {
  const RetailerListScreen({super.key});

  @override
  ConsumerState<RetailerListScreen> createState() => _RetailerListScreenState();
}

class _RetailerListScreenState extends ConsumerState<RetailerListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final online = ref.watch(networkMonitorProvider).online;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Điểm bán phụ trách'),
        actions: const [CatalogSyncButton()],
      ),
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
            child: TextField(
              onTapOutside: releaseFocus,
              decoration: const InputDecoration(
                hintText: 'Tìm mã, tên hoặc địa chỉ',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _query = value.trim().toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: AsyncBody<CatalogData>(
              value: catalog,
              onRetry: () => ref.invalidate(catalogProvider),
              builder: (data) {
                if (!data.hasSnapshot) {
                  return const EmptyState(
                    icon: Icons.cloud_download_outlined,
                    title: 'Chưa có dữ liệu điểm bán',
                    message:
                        'Kết nối mạng và bấm nút đồng bộ trên thanh tiêu đề '
                        'để tải danh sách được phân công.',
                  );
                }

                final retailers = data.retailers.where((retailer) {
                  return _query.isEmpty ||
                      retailer.code.toLowerCase().contains(_query) ||
                      retailer.name.toLowerCase().contains(_query) ||
                      retailer.address.toLowerCase().contains(_query);
                }).toList()
                  ..sort((a, b) => a.code.compareTo(b.code));

                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    InfoBanner(
                      icon: online
                          ? Icons.info_outline
                          : Icons.cloud_off_outlined,
                      text:
                          '${online ? 'Dữ liệu đã lưu' : 'Đang dùng dữ liệu đã lưu'}'
                          ' · Dữ liệu đồng bộ ${_stamp(data.lastSyncAt)}.\n'
                          'Danh sách theo phân công tại lần cập nhật này. '
                          'Điều kiện đặt hàng được kiểm tra lại với máy chủ.',
                    ),
                    Text(
                      '${data.retailers.length} điểm bán phụ trách',
                      style: AppText.cardTitle,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (data.retailers.isEmpty)
                      const EmptyState(
                        icon: Icons.storefront_outlined,
                        title: 'Chưa có điểm bán được phân công',
                        message:
                            'Nếu vừa được phân công, hãy cập nhật dữ liệu đồng bộ.',
                      )
                    else if (retailers.isEmpty)
                      const EmptyState(
                        title: 'Không có điểm bán phù hợp',
                        message: 'Thử mã, tên hoặc địa chỉ khác.',
                      )
                    else
                      for (final retailer in retailers)
                        RetailerSummaryCard(
                          retailer: retailer,
                          onTap: () {
                            context.push(
                              AppRoutes.salesRetailerDetail(retailer.code),
                            );
                          },
                        ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _stamp(DateTime? value) {
    if (value == null) return 'chưa xác định';
    return AppDates.timeDay(value);
  }
}
