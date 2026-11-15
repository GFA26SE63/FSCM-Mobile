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
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';
import 'package:fscm_mobile/shared/widgets/empty_state.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/kv_row.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';

/// "Khai báo retailer": declarations created by the signed-in Sales
/// (`GET /retailers?scope=mine`) and their approval state.
class DeclarationsScreen extends ConsumerWidget {
  const DeclarationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(declarationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Khai báo retailer')),
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: <Widget>[
              const InfoBanner(
                  text:
                      'Admin / Operator duyệt, cấp mã điểm bán 8 số và tạo tài khoản Retailer App.'),
              if (list.isEmpty)
                const EmptyState(title: 'Chưa có khai báo nào.'),
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
      showAppSnack(context, 'Cần thêm ít nhất 1 MLOR trước khi gửi duyệt.',
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
        showAppSnack(context, 'Đã gửi ${d.code} cho Admin / Operator.');
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
          title: Row(
            children: <Widget>[
              Expanded(
                  child: Text('${d.code} · ${d.name}',
                      style: const TextStyle(fontWeight: FontWeight.w800))),
              StatusChip(label: d.status.label, tone: d.status.tone),
            ],
          ),
          subtitle: Text(
              '${d.address.isEmpty ? '—' : d.address}\nNhóm ${d.salesGroupCode}',
              style:
                  const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
          children: <Widget>[
            if (d.status == DeclarationStatus.rejected)
              InfoBanner(
                  tone: StatusTone.danger,
                  title: 'Lý do từ chối',
                  text: d.reviewReason.isEmpty ? '—' : d.reviewReason),
            if (d.status == DeclarationStatus.pendingApproval)
              const InfoBanner(
                  text:
                      'Đang chờ Admin / Operator kiểm tra. Chưa đặt hàng được cho điểm bán này.'),
            if (d.status == DeclarationStatus.active)
              InfoBanner(
                  tone: StatusTone.success,
                  text:
                      'Đã duyệt · hạn thanh toán ${d.creditTermDays} ngày. Tài khoản Retailer đã được tạo và email thông báo đã gửi tới ${d.email}.'),
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
              const SizedBox(height: 8),
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
                  const SizedBox(width: 12),
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
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
