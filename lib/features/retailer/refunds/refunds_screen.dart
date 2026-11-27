import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/refund.dart';
import 'package:fscm_mobile/data/repositories/finance_repository.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/chip_filter_bar.dart';
import 'package:fscm_mobile/shared/widgets/empty_state.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';

final _refundFilterProvider = StateProvider.autoDispose<bool?>((ref) => null);

/// Read-only list of the retailer's refund records. The transfer happens
/// outside the system; Operator records it and Admin verifies the proof.
class RefundsScreen extends ConsumerWidget {
  const RefundsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(retailerRefundsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Hoàn tiền')),
      body: AsyncBody<List<RetailerRefund>>(
        value: value,
        onRetry: () => ref.invalidate(retailerRefundsProvider),
        builder: (list) {
          if (list.isEmpty) {
            return const EmptyState(
                icon: Icons.currency_exchange,
                title: 'Chưa có phiếu hoàn tiền nào.');
          }
          final open = ref.watch(_refundFilterProvider);
          final shown = open == null
              ? list
              : list.where((r) => r.isOpen == open).toList();
          return Column(children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: ChipFilterBar<bool?>(
                selected: open,
                onSelected: (v) =>
                    ref.read(_refundFilterProvider.notifier).state = v,
                options: const <ChipOption<bool?>>[
                  ChipOption(null, 'Tất cả'),
                  ChipOption(true, 'Đang xử lý'),
                  ChipOption(false, 'Đã hoàn'),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.refresh(retailerRefundsProvider.future),
                child: shown.isEmpty
                    ? ListView(children: const <Widget>[
                        EmptyState(
                            icon: Icons.filter_alt_off_outlined,
                            title: 'Không có phiếu hoàn phù hợp bộ lọc.'),
                      ])
                    : ListView.builder(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: shown.length,
                        itemBuilder: (context, i) => _RefundCard(shown[i]),
                      ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

/// Transfer-proof thumbnail; tap for full size (same pattern as claim evidence).
class _ProofThumb extends StatelessWidget {
  const _ProofThumb(this.url);

  final String url;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          child:
              InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(url,
            width: 72,
            height: 72,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
                width: 72,
                height: 72,
                color: AppColors.border,
                child: const Icon(Icons.broken_image_outlined))),
      ),
    );
  }
}

class _RefundCard extends StatelessWidget {
  const _RefundCard(this.r);

  final RetailerRefund r;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: r.orderCode.isEmpty
          ? null
          : () => context.push(AppRoutes.rtOrderDetail(r.orderCode)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              Text(r.orderCode, style: AppText.strong),
              StatusChip(label: r.statusText, tone: r.statusTone),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(Money.format(r.amount), style: AppText.cardTitle),
          Text('Đơn ${r.paymentText}', style: AppText.mutedSmall),
          if (r.reason.isNotEmpty)
            Text('Lý do: ${r.reason}', style: AppText.bodySmall),
          if (r.transferredAt != null)
            Text('Chuyển tiền: ${AppDates.timeDay(r.transferredAt)}',
                style: AppText.bodySmall),
          if (r.transactionReference.isNotEmpty)
            Text('Mã giao dịch: ${r.transactionReference}',
                style: AppText.bodySmall),
          if (r.verifiedAt != null)
            Text('Xác minh: ${AppDates.timeDay(r.verifiedAt)}',
                style: AppText.bodySmall),
          if (r.evidenceUrl.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.s6),
            const Text('Bằng chứng chuyển tiền (chạm để phóng to)',
                style: AppText.mutedSmall),
            const SizedBox(height: AppSpacing.xs),
            _ProofThumb(r.evidenceUrl),
          ],
          if (r.status == 'EvidenceRejected') ...<Widget>[
            const SizedBox(height: AppSpacing.s6),
            const InfoBanner(
                tone: StatusTone.warning,
                icon: Icons.hourglass_top,
                text:
                    'Chứng từ chuyển tiền bị trả lại, đang chờ nộp lại. Số tiền cần hoàn không đổi.'),
          ],
        ],
      ),
    );
  }
}
