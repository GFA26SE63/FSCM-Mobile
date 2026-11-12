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
import 'package:fscm_mobile/shared/widgets/dialogs.dart';
import 'package:fscm_mobile/shared/widgets/empty_state.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';

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
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final c = list[i];
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                            child: Text(c.code,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800))),
                        StatusChip(label: c.statusText, tone: c.statusTone),
                      ],
                    ),
                    Text('${c.orderCode} · ${c.sku} ${c.name}'),
                    Text('${c.typeText} · Đề nghị: ${c.settlementText}'),
                    if (c.approvedSettlementMethod.isNotEmpty)
                      Text('Admin duyệt: ${c.approvedSettlementText}'),
                    Text(
                      'Yêu cầu ${c.requestedQuantity == 0 ? c.shortfall : c.requestedQuantity} thùng · duyệt ${c.approvedQuantity ?? '—'} · xử lý ${c.handledQuantity ?? '—'}',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 13),
                    ),
                    if (c.note.isNotEmpty)
                      Text('"${c.note}"', style: const TextStyle(fontSize: 13)),
                    _EvidenceStrip(
                        complaintId: c.id,
                        // Images can be replaced only while the claim has no decision yet.
                        onRemove: c.acceptsEvidence
                            ? (e) => _removeEvidence(context, ref, c, e)
                            : null),
                    if (c.needsEvidence) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                          'Yêu cầu bổ sung: ${c.evidenceRequestReason.isEmpty ? 'Vui lòng gửi thêm ảnh bằng chứng.' : c.evidenceRequestReason}',
                          style: const TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600)),
                    ],
                    if (c.response.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text('Phản hồi: ${c.response}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
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
                          style: const TextStyle(fontSize: 13)),
                    for (final doc in c.documents)
                      Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                              '${doc['kind'] == 'ReturnOrder' ? 'Phiếu trả hàng' : 'Phiếu thu hồi'} ${doc['code']} · ${doc['status'] == 'Pending' ? 'Chờ xử lý' : doc['status'] == 'Waived' ? 'Miễn xử lý' : 'Đã xử lý'}')),
                    if (c.acceptsEvidence || c.canCancel)
                      Wrap(spacing: 8, children: <Widget>[
                        if (c.acceptsEvidence)
                          TextButton.icon(
                              onPressed: () => _addEvidence(context, ref, c),
                              icon: const Icon(Icons.add_a_photo_outlined),
                              label: const Text('Bổ sung ảnh')),
                        if (c.canCancel)
                          TextButton.icon(
                              onPressed: () => _cancel(context, ref, c),
                              icon: const Icon(Icons.cancel_outlined,
                                  color: AppColors.danger),
                              label: const Text('Hủy yêu cầu',
                                  style: TextStyle(color: AppColors.danger))),
                      ]),
                    Text(AppDates.timeDay(c.createdAt),
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

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
