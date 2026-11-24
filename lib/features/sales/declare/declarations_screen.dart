import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/retailer_declaration.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';
import 'package:fscm_mobile/data/repositories/retailer_repository.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';
import 'package:fscm_mobile/shared/widgets/empty_state.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/kv_row.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';

/// "Khai báo điểm bán": declarations created by the signed-in Sales
/// (`GET /retailers?scope=mine`) and their approval state.
class DeclarationsScreen extends ConsumerWidget {
  const DeclarationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(declarationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Khai báo điểm bán')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.salesDeclare),
        icon: const Icon(Icons.add),
        label: const Text('Khai báo mới'),
      ),
      body: AsyncBody<List<RetailerDeclaration>>(
        value: value,
        onRetry: () => ref.invalidate(declarationsProvider),
        builder: (list) => RefreshIndicator(
          onRefresh: () => ref.refresh(declarationsProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 90),
            children: <Widget>[
              const InfoBanner(
                  text:
                      'Quản trị viên / nhân viên vận hành duyệt, cấp mã điểm bán 8 số và tạo tài khoản điểm bán trên ứng dụng.'),
              if (list.isEmpty)
                const EmptyState(title: 'Chưa có khai báo nào.')
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child:
                      Text('${list.length} khai báo', style: AppText.cardTitle),
                ),
              for (final d in list) _Tile(declaration: d),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends ConsumerStatefulWidget {
  const _Tile({required this.declaration});

  final RetailerDeclaration declaration;

  @override
  ConsumerState<_Tile> createState() => _TileState();
}

class _TileState extends ConsumerState<_Tile> {
  bool _busy = false;

  Future<void> _submit() async {
    final d = widget.declaration;
    if (d.mlorDeclarations.isEmpty) {
      showAppSnack(context,
          'Cần thêm ít nhất một yêu cầu hạn sử dụng trước khi gửi duyệt.',
          error: true);
      return;
    }
    final ok = await confirmDialog(context,
        title: 'Gửi duyệt ${d.code}?',
        message:
            'Sau khi gửi, khai báo không sửa được cho tới khi có kết quả duyệt.',
        confirmLabel: 'Gửi duyệt');
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(retailerRepositoryProvider).submitForReview(d.id);
      ref.read(dataVersionProvider.notifier).state++;
      if (mounted) {
        showAppSnack(context,
            'Đã gửi ${d.code} cho quản trị viên / nhân viên vận hành.');
      }
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.declaration;
    return AppCard(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          // Name on the left, status chip always on the right of the first line.
          title: LayoutBuilder(
            builder: (context, box) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                    child:
                        Text('${d.code} · ${d.name}', style: AppText.strong)),
                const SizedBox(width: AppSpacing.sm),
                // A long label wraps inside the chip instead of overflowing.
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: box.maxWidth * 0.5),
                  child: StatusChip(label: d.status.label, tone: d.status.tone),
                ),
              ],
            ),
          ),
          subtitle: Text(
              '${d.address.isEmpty ? '—' : d.address}\nNhóm ${d.salesGroupCode}',
              style: AppText.mutedSmall),
          children: <Widget>[
            if (d.status == DeclarationStatus.rejected)
              InfoBanner(
                  tone: StatusTone.danger,
                  title: 'Lý do từ chối',
                  text: d.reviewReason.isEmpty ? '—' : d.reviewReason),
            if (d.status == DeclarationStatus.pendingApproval)
              const InfoBanner(
                  text:
                      'Đang chờ quản trị viên / nhân viên vận hành kiểm tra. Chưa đặt hàng được cho điểm bán này.'),
            if (d.status == DeclarationStatus.active)
              InfoBanner(
                  tone: StatusTone.success,
                  text:
                      'Đã duyệt · hạn thanh toán ${d.creditTermDays} ngày. Tài khoản điểm bán đã được tạo và email thông báo đã gửi tới ${d.email}.'),
            KvRow('Người liên hệ', d.contactName),
            KvRow('Số điện thoại', d.phone),
            KvRow('Email', d.email),
            KvRow('Loại hình',
                '${d.retailerType.label} · quy mô ${d.storeSizeCategory} · ${d.storeSizeSquareMeters.toStringAsFixed(0)} m²'),
            KvRow('Doanh thu dự báo',
                '${Money.format(d.forecastRevenue)} / tháng'),
            KvRow('Khả năng nhập',
                '${d.purchasingCapacity.toStringAsFixed(0)} thùng / tháng · ${d.purchaseFrequencyPerMonth} lần / tháng'),
            KvRow('Xếp loại tiềm năng', d.potentialClass),
            KvRow(
                'MLOR',
                d.mlorDeclarations.isEmpty
                    ? 'Chưa khai báo'
                    : '${d.mlorDeclarations.length} dòng'),
            if (d.assessmentNote.isNotEmpty) KvRow('Ghi chú', d.assessmentNote),
            if (d.status.isEditable) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () =>
                              context.push(AppRoutes.salesDeclare, extra: d),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Sửa'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _submit,
                      icon: const Icon(Icons.send_outlined),
                      label: Text(_busy ? 'Đang gửi...' : 'Gửi duyệt'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
