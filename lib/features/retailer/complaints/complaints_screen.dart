import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/data/models/complaint.dart';
import 'package:fscm_mobile/data/repositories/loyalty_repository.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/chip_filter_bar.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';
import 'package:fscm_mobile/shared/widgets/empty_state.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';

/// Own complaints (KN-yyMMdd-nn) with their processing status, evidence images, evidence follow-up
/// and cancel (only while the claim has no decision yet).
class ComplaintsScreen extends ConsumerWidget {
  const ComplaintsScreen({super.key});

  Future<void> _addEvidence(
      BuildContext context, WidgetRef ref, Complaint c) async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    try {
      await ref.read(loyaltyRepositoryProvider).addComplaintEvidence(
          c.id, picked.path,
          bytes: await picked.readAsBytes(), fileName: picked.name);
      ref.invalidate(complaintEvidenceProvider(c.id));
      ref.invalidate(complaintsProvider);
      if (context.mounted) showAppSnack(context, 'Đã bổ sung bằng chứng.');
    } on ApiException catch (e) {
      if (context.mounted) showAppSnack(context, e.message, error: true);
    }
  }

  Future<void> _removeEvidence(BuildContext context, WidgetRef ref, Complaint c,
      ComplaintEvidence e) async {
    final ok = await confirmDialog(context,
        title: 'Xóa ảnh bằng chứng',
        message: 'Xóa ảnh ${e.fileName}? Bạn có thể chọn lại ảnh khác.',
        confirmLabel: 'Xóa',
        cancelLabel: 'Giữ lại');
    if (!ok) return;
    try {
      await ref
          .read(loyaltyRepositoryProvider)
          .removeComplaintEvidence(c.id, e.id);
      ref.invalidate(complaintEvidenceProvider(c.id));
      if (context.mounted) showAppSnack(context, 'Đã xóa ảnh.');
    } on ApiException catch (err) {
      if (context.mounted) showAppSnack(context, err.message, error: true);
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, Complaint c) async {
    final ok = await confirmDialog(context,
        title: 'Hủy khiếu nại',
        message:
            'Hủy khiếu nại ${c.code}? Bạn có thể gửi khiếu nại mới cho phần hàng này sau khi hủy.',
        confirmLabel: 'Hủy khiếu nại',
        cancelLabel: 'Giữ lại');
    if (!ok) return;
    try {
      await ref.read(loyaltyRepositoryProvider).cancelComplaint(c.id);
      ref.invalidate(complaintsProvider);
      if (context.mounted) showAppSnack(context, 'Đã hủy khiếu nại ${c.code}.');
    } on ApiException catch (e) {
      if (context.mounted) showAppSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(complaintsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Yêu cầu')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.rtComplaintNew),
        icon: const Icon(Icons.add),
        label: const Text('Tạo yêu cầu'),
      ),
      body: AsyncBody<List<Complaint>>(
        value: value,
        onRetry: () => ref.invalidate(complaintsProvider),
        builder: (list) {
          if (list.isEmpty) {
            return const EmptyState(
                icon: Icons.report_gmailerrorred_outlined,
                title: 'Chưa có yêu cầu nào.');
          }
          final filter = ref.watch(_complaintFilterProvider);
          final shown = filter == null
              ? list
              : list.where((c) => c.status.group == filter).toList();
          return Column(children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: ChipFilterBar<_ComplaintGroup?>(
                selected: filter,
                onSelected: (v) =>
                    ref.read(_complaintFilterProvider.notifier).state = v,
                options: const <ChipOption<_ComplaintGroup?>>[
                  ChipOption(null, 'Tất cả'),
                  ChipOption(_ComplaintGroup.waiting, 'Chờ xử lý'),
                  ChipOption(_ComplaintGroup.handling, 'Đang xử lý'),
                  ChipOption(_ComplaintGroup.done, 'Đã xử lý'),
                  ChipOption(_ComplaintGroup.closed, 'Từ chối / Hủy'),
                ],
              ),
            ),
            Expanded(
                child: shown.isEmpty
                    ? const EmptyState(
                        icon: Icons.filter_alt_off_outlined,
                        title: 'Không có yêu cầu phù hợp bộ lọc.')
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 90),
                        itemCount: shown.length,
                        itemBuilder: (context, i) {
                          final c = shown[i];
                          return AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                // Header: claim code + status chip (prototype complaint card).
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: AppSpacing.sm,
                                  runSpacing: AppSpacing.xs,
                                  children: <Widget>[
                                    Text(c.code, style: AppText.strong),
                                    StatusChip(
                                        label: c.statusText,
                                        tone: c.statusTone),
                                  ],
                                ),
                                Text(AppDates.timeDay(c.createdAt),
                                    style: AppText.mutedSmall),
                                const SizedBox(height: AppSpacing.sm),
                                Text('${c.orderCode} · ${c.sku} ${c.name}',
                                    style: AppText.cardTitle
                                        .copyWith(fontSize: 14)),
                                Text(
                                    '${c.typeText} · Đề nghị: ${c.settlementText}',
                                    style: AppText.bodyMedium),
                                if (c.approvedSettlementMethod.isNotEmpty)
                                  Text(
                                      'Quản trị viên duyệt: ${c.approvedSettlementText}',
                                      style: AppText.bodyMedium),
                                Text(
                                  'Yêu cầu ${c.requestedQuantity == 0 ? c.shortfall : c.requestedQuantity} thùng · duyệt ${c.approvedQuantity ?? '—'} · xử lý ${c.handledQuantity ?? '—'}',
                                  style: AppText.mutedSmall,
                                ),
                                if (c.note.isNotEmpty)
                                  Text('"${c.note}"', style: AppText.bodySmall),
                                _EvidenceStrip(
                                    complaintId: c.id,
                                    // Images can be replaced only while the claim has no decision yet.
                                    onRemove: c.acceptsEvidence
                                        ? (e) =>
                                            _removeEvidence(context, ref, c, e)
                                        : null),
                                if (c.needsEvidence) ...<Widget>[
                                  const SizedBox(height: AppSpacing.s6),
                                  InfoBanner(
                                      tone: StatusTone.warning,
                                      icon: Icons.add_a_photo_outlined,
                                      text:
                                          'Yêu cầu bổ sung: ${c.evidenceRequestReason.isEmpty ? 'Vui lòng gửi thêm ảnh bằng chứng.' : c.evidenceRequestReason}'),
                                ],
                                if (c.response.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: AppSpacing.xs),
                                  InfoBanner(
                                      tone: StatusTone.success,
                                      icon: Icons.chat_bubble_outline,
                                      text: 'Phản hồi: ${c.response}'),
                                ],
                                if (c.financialAdjustmentApplied &&
                                    c.debtOffsetAmount + c.refundAmount !=
                                        c.adjustmentAmount)
                                  const Text(
                                      'Lịch sử cũ đã điều chỉnh nghĩa vụ thanh toán. Xem công nợ và phiếu hoàn để đối soát chi tiết.'),
                                if (c.financialAdjustmentApplied &&
                                    c.debtOffsetAmount + c.refundAmount ==
                                        c.adjustmentAmount)
                                  Text(
                                      'Đã chốt: cấn trừ nợ ${Money.format(c.debtOffsetAmount)}; phiếu hoàn ${Money.format(c.refundAmount)}${c.refundId.isEmpty ? '' : ' (đã tạo, đang theo dõi chi trả)'}.',
                                      style: AppText.bodySmall),
                                if (c.refundId.isNotEmpty)
                                  TextButton.icon(
                                      onPressed: () =>
                                          context.push(AppRoutes.rtRefunds),
                                      icon: const Icon(Icons.currency_exchange),
                                      label: const Text('Xem phiếu hoàn')),
                                for (final doc in c.documents)
                                  Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                          '${doc['kind'] == 'ReturnOrder' ? 'Phiếu trả hàng' : 'Phiếu thu hồi'} ${doc['code']} · ${doc['status'] == 'Pending' ? 'Chờ xử lý' : doc['status'] == 'Waived' ? 'Miễn xử lý' : 'Đã xử lý'}')),
                                if (c.acceptsEvidence || c.canCancel)
                                  Wrap(spacing: 8, children: <Widget>[
                                    if (c.acceptsEvidence)
                                      TextButton.icon(
                                          onPressed: () =>
                                              _addEvidence(context, ref, c),
                                          icon: const Icon(
                                              Icons.add_a_photo_outlined),
                                          label: const Text('Bổ sung ảnh')),
                                    if (c.canCancel)
                                      TextButton.icon(
                                          onPressed: () =>
                                              _cancel(context, ref, c),
                                          icon: const Icon(
                                              Icons.cancel_outlined,
                                              color: AppColors.danger),
                                          label: const Text('Hủy yêu cầu',
                                              style: TextStyle(
                                                  color: AppColors.danger))),
                                  ]),
                              ],
                            ),
                          );
                        },
                      )),
          ]);
        },
      ),
    );
  }
}

enum _ComplaintGroup { waiting, handling, done, closed }

extension on ComplaintStatus {
  _ComplaintGroup get group => switch (this) {
        ComplaintStatus.open => _ComplaintGroup.waiting,
        ComplaintStatus.inProgress => _ComplaintGroup.handling,
        ComplaintStatus.approved ||
        ComplaintStatus.resolved =>
          _ComplaintGroup.done,
        ComplaintStatus.rejected ||
        ComplaintStatus.cancelled =>
          _ComplaintGroup.closed,
      };
}

/// Selected status group of the request list (null = all). The list arrives
/// whole from the Backend, so this filter is exact.
final _complaintFilterProvider =
    StateProvider.autoDispose<_ComplaintGroup?>((ref) => null);

/// Thumbnails of the evidence images already stored for a claim. Tap to view full size.
class _EvidenceStrip extends ConsumerWidget {
  const _EvidenceStrip({required this.complaintId, this.onRemove});
  final String complaintId;
  final void Function(ComplaintEvidence evidence)? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (complaintId.isEmpty) return const SizedBox.shrink();
    final items = ref.watch(complaintEvidenceProvider(complaintId));
    return items.when(
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => Stack(children: <Widget>[
                GestureDetector(
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => Dialog(
                      child: InteractiveViewer(
                          child:
                              Image.network(list[i].url, fit: BoxFit.contain)),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(list[i].url,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            width: 72,
                            height: 72,
                            color: AppColors.border,
                            child: const Icon(Icons.broken_image_outlined))),
                  ),
                ),
                if (onRemove != null)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: InkWell(
                      onTap: () => onRemove!(list[i]),
                      child: Container(
                        decoration: const BoxDecoration(
                            color: Colors.black54, shape: BoxShape.circle),
                        padding: const EdgeInsets.all(3),
                        child: const Icon(Icons.close,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        );
      },
    );
  }
}
