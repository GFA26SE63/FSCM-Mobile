import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/network_monitor.dart';
import 'package:fscm_mobile/data/models/retailer.dart';
import 'package:fscm_mobile/data/repositories/retailer_repository.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';

class RetailerOrderAction extends ConsumerWidget {
  const RetailerOrderAction({
    super.key,
    required this.retailer,
  });

  final Retailer retailer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(networkMonitorProvider).online;

    if (retailer.id.isEmpty) {
      return const InfoBanner(
        text: 'Điểm bán thiếu ID máy chủ. Hãy cập nhật snapshot.',
      );
    }

    if (!online) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InfoBanner(
            icon: Icons.cloud_off_outlined,
            text: 'Chưa kiểm tra được quyền đặt hàng hiện tại. '
                'Thông tin đang hiển thị là dữ liệu đã lưu trên máy.',
          ),
          if (retailer.status == 'Active')
            FilledButton.icon(
              onPressed: () {
                context.push(AppRoutes.salesNewOrder(retailer.code));
              },
              icon: const Icon(Icons.edit_note),
              label: const Text('Chuẩn bị đơn offline'),
            )
          else
            const InfoBanner(
              text: 'Theo snapshot hiện có, điểm bán chưa hoạt động. '
                  'Kết nối mạng để kiểm tra lại.',
            ),
        ],
      );
    }

    final eligibility = ref.watch(
      retailerOrderEligibilityProvider(retailer.id),
    );

    return eligibility.when(
      skipLoadingOnRefresh: false,
      skipLoadingOnReload: false,
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoBanner(text: ApiException.describe(error)),
          OutlinedButton.icon(
            onPressed: () {
              ref.invalidate(
                retailerOrderEligibilityProvider(retailer.id),
              );
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Kiểm tra lại'),
          ),
        ],
      ),
      data: (result) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InfoBanner(
              text: result.isEligible
                  ? 'Máy chủ xác nhận đủ điều kiện đặt hàng.\n'
                      'Kỳ hạn công nợ hiện tại: '
                      '${result.creditTermDays} ngày.'
                  : result.denialMessage,
            ),
            if (result.isEligible)
              FilledButton.icon(
                onPressed: () {
                  context.push(AppRoutes.salesNewOrder(retailer.code));
                },
                icon: const Icon(Icons.shopping_cart_outlined),
                label: const Text('Tạo đơn hàng'),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                ref.invalidate(
                  retailerOrderEligibilityProvider(retailer.id),
                );
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Kiểm tra lại điều kiện'),
            ),
          ],
        );
      },
    );
  }
}
