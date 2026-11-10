import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/data/repositories/catalog_repository.dart';
import 'package:fscm_mobile/features/sales/products/catalog_sync_button.dart';
import 'package:fscm_mobile/features/sales/retailers/widgets/retailer_order_action.dart';
import 'package:fscm_mobile/features/sales/retailers/widgets/retailer_summary_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/empty_state.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';

class RetailerDetailScreen extends ConsumerWidget {
  const RetailerDetailScreen({
    super.key,
    required this.code,
  });

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết điểm bán'),
        actions: const [CatalogSyncButton()],
      ),
      body: AsyncBody<CatalogData>(
        value: catalog,
        onRetry: () => ref.invalidate(catalogProvider),
        builder: (data) {
          final retailer = data.retailer(code);

          if (!data.hasSnapshot || retailer == null) {
            return const EmptyState(
              icon: Icons.storefront_outlined,
              title: 'Không có điểm bán trong snapshot hiện tại',
              message:
                  'Điểm bán có thể chưa được tải hoặc phân công đã thay đổi. '
                  'Hãy cập nhật dữ liệu.',
            );
          }

          final timestamp = data.lastSyncAt?.toLocal();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              RetailerSummaryCard(retailer: retailer),
              InfoBanner(
                text: timestamp == null
                    ? 'Thông tin lấy từ dữ liệu đã lưu trên máy.'
                    : 'Thông tin theo snapshot '
                        '${_stamp(timestamp)}. '
                        'Trạng thái và công nợ có thể đã thay đổi; '
                        'xem kết quả kiểm tra bên dưới trước khi đặt hàng.',
              ),
              const SizedBox(height: 8),
              Text(
                'Đặt hàng',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              RetailerOrderAction(
                key: ValueKey(retailer.id),
                retailer: retailer,
              ),
            ],
          );
        },
      ),
    );
  }

  String _stamp(DateTime value) {
    String pad(int number) => number.toString().padLeft(2, '0');

    return '${pad(value.hour)}:${pad(value.minute)} '
        '${pad(value.day)}/${pad(value.month)}/${value.year}';
  }
}
