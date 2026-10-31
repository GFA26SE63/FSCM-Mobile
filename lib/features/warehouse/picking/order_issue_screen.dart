import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/quantity.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/run_picking.dart';
import 'package:fscm_mobile/data/models/shipment.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';
import 'package:fscm_mobile/data/repositories/warehouse_repository.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/kv_row.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';

/// F93 + F96: whether this order may leave, and the confirmation that this
/// warehouse's part of it did.
///
/// The two belong on one screen because the second is only legible next to the
/// first. An order is all or nothing at the door: every warehouse part must be
/// picked and the payment condition met before any part moves, so the keeper
/// standing in one warehouse has to be able to see why a part that is ready on
/// their shelf still cannot go.
///
/// The verdict is never computed here. [OrderShipmentReadiness.isReady] is the
/// server's, and the confirm button is enabled on nothing else - the parts and
/// the blocking reasons are shown to explain the answer, not to be recombined
/// into one of the app's own. An app that worked it out locally would eventually
/// disagree with the server about a payment it cannot see.
class OrderIssueScreen extends ConsumerWidget {
  const OrderIssueScreen({
    super.key,
    required this.pickingCode,
    required this.orderCode,
  });

  final String pickingCode;
  final String orderCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sheetValue = ref.watch(pickingDetailProvider(pickingCode));
    return Scaffold(
      appBar: AppBar(title: Text('Xuất kho · $orderCode')),
      body: AsyncBody<RunPickingSheet>(
        value: sheetValue,
        onRetry: () => ref.invalidate(pickingDetailProvider(pickingCode)),
        builder: (sheet) {
          final orderId = sheet.orderIdOf(orderCode);
          if (orderId == null) {
            return const Center(
                child: Text('Đơn này không có phần hàng trên phiếu soạn.'));
          }
          return _Body(sheet: sheet, orderCode: orderCode, orderId: orderId);
        },
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.sheet,
    required this.orderCode,
    required this.orderId,
  });

  final RunPickingSheet sheet;
  final String orderCode;
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(orderIssueProvider(orderId));
    return AsyncBody<OrderIssueView>(
      value: value,
      onRetry: () => ref.invalidate(orderIssueProvider(orderId)),
      builder: (view) {
        final readiness = view.readiness;
        final mine = _mine(view.shipments, sheet.warehouseId);
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(orderIssueProvider(orderId)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _Verdict(readiness: readiness, mine: mine),
              const SectionTitle('Phần hàng của kho này'),
              _PartsCard(sheet: sheet, orderCode: orderCode, mine: mine),
              const SectionTitle('Các kho khác của đơn'),
              _OtherWarehouses(readiness: readiness, mine: mine),
              if (readiness.blockingReasons.isNotEmpty) ...<Widget>[
                const SectionTitle('Đang bị giữ vì'),
                for (final reason in readiness.blockingReasons)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Padding(
                          padding: EdgeInsets.only(top: 2, right: 8),
                          child: Icon(Icons.block,
                              size: 15, color: AppColors.danger),
                        ),
                        Expanded(child: Text(reason)),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 10),
              _IssueAction(
                  sheet: sheet,
                  orderId: orderId,
                  readiness: readiness,
                  mine: mine),
            ],
          ),
        );
      },
    );
  }

  static Shipment? _mine(List<Shipment> shipments, String warehouseId) {
    for (final shipment in shipments) {
      if (shipment.warehouseId == warehouseId) return shipment;
    }
    return null;
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({required this.readiness, required this.mine});

  final OrderShipmentReadiness readiness;
  final Shipment? mine;

  @override
  Widget build(BuildContext context) {
    if (mine != null && mine!.hasLeft) {
      return InfoBanner(
        tone: StatusTone.success,
        icon: Icons.check_circle_outline,
        title: 'Phần hàng của kho này đã xuất',
        text: mine!.issuedAt == null
            ? 'Trạng thái do máy chủ trả về: ${mine!.status.label}.'
            : 'Xuất lúc ${AppDates.timeDay(mine!.issuedAt)} · trạng thái ${mine!.status.label}.',
      );
    }
    if (readiness.isReady) {
      return const InfoBanner(
        tone: StatusTone.primary,
        icon: Icons.local_shipping_outlined,
        title: 'Đơn đã sẵn sàng xuất',
        text:
            'Mọi phần hàng theo kho đã soạn đủ và điều kiện thanh toán đã đạt.',
      );
    }
    return InfoBanner(
      tone: StatusTone.warning,
      icon: Icons.pause_circle_outline,
      title: 'Chưa được xuất',
      text: readiness.hasException
          ? 'Đơn đang Cần xử lý vì có kho báo thiếu/hỏng. Người có quyền phải xử lý ngoại lệ hoặc hủy đơn hợp lệ trước.'
          : readiness.paymentSettled
              ? 'Còn kho chưa soạn đủ. Cả đơn phải sẵn sàng thì mới xuất được phần nào.'
              : 'Đơn chưa đạt điều kiện thanh toán.',
    );
  }
}

class _PartsCard extends StatelessWidget {
  const _PartsCard({
    required this.sheet,
    required this.orderCode,
    required this.mine,
  });

  final RunPickingSheet sheet;
  final String orderCode;
  final Shipment? mine;

  @override
  Widget build(BuildContext context) {
    final parts = sheet.partsOf(orderCode);
    final total = parts.fold<double>(0, (s, p) => s + p.split.requiredQuantity);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (mine != null)
            KvRow(
                'Phiếu giao', '${mine!.shipmentCode} · ${mine!.warehouseName}'),
          KvRow('Phiếu soạn', sheet.pickingCode),
          const SizedBox(height: 6),
          // Order, batch and quantity, which is what has to be on screen before
          // anyone confirms anything left the building.
          for (final part in parts)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                        '${part.gather.sku} · batch ${part.gather.batchCode}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Text(Qty.cartons(part.split.requiredQuantity)),
                ],
              ),
            ),
          const Divider(height: 18),
          KvRow('Tổng phần kho này', Qty.cartons(total), bold: true),
        ],
      ),
    );
  }
}

class _OtherWarehouses extends StatelessWidget {
  const _OtherWarehouses({required this.readiness, required this.mine});

  final OrderShipmentReadiness readiness;
  final Shipment? mine;

  @override
  Widget build(BuildContext context) {
    final others = mine == null
        ? readiness.parts
        : readiness.othersThan(mine!.warehouseId);
    if (others.isEmpty) {
      return const AppCard(
        child: Text('Đơn này chỉ lấy hàng từ kho của bạn.'),
      );
    }
    return AppCard(
      child: Column(
        children: <Widget>[
          for (final part in others)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(part.warehouseCode,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        if ((part.exceptionReason ?? '').isNotEmpty)
                          Text(part.exceptionReason!,
                              style: const TextStyle(
                                  fontSize: 12.5, color: AppColors.danger)),
                      ],
                    ),
                  ),
                  StatusChip(label: part.status.label, tone: part.status.tone),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _IssueAction extends ConsumerStatefulWidget {
  const _IssueAction({
    required this.sheet,
    required this.orderId,
    required this.readiness,
    required this.mine,
  });

  final RunPickingSheet sheet;
  final String orderId;
  final OrderShipmentReadiness readiness;
  final Shipment? mine;

  @override
  ConsumerState<_IssueAction> createState() => _IssueActionState();
}

class _IssueActionState extends ConsumerState<_IssueAction> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final mine = widget.mine;
    if (mine == null) {
      return const InfoBanner(
        tone: StatusTone.neutral,
        icon: Icons.help_outline,
        text:
            'Chưa có phiếu giao cho phần hàng của kho này. Phiếu giao được tạo khi phương án của đợt được duyệt.',
      );
    }
    if (mine.hasLeft) return const SizedBox.shrink();

    // The only condition. Picking being finished here is not enough and is
    // deliberately not consulted.
    final allowed = widget.readiness.isReady;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FilledButton.icon(
          onPressed: allowed && !_busy ? () => _confirm(context, mine) : null,
          icon: const Icon(Icons.local_shipping_outlined),
          label: Text(_busy ? 'Đang xử lý...' : 'Xác nhận xuất'),
        ),
        const SizedBox(height: 6),
        Text(
          allowed
              ? 'Xác nhận hàng đã rời kho. Tồn thực tế và lượng giữ giảm cùng lúc — khác bước quét soạn và khác xác nhận khách nhận hàng.'
              : 'Máy chủ chưa cho xuất đơn này. Nút chỉ mở khi cả đơn sẵn sàng.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
        ),
      ],
    );
  }

  Future<void> _confirm(BuildContext context, Shipment mine) async {
    final ok = await confirmDialog(
      context,
      title: 'Xác nhận xuất ${mine.shipmentCode}?',
      message:
          'Hàng rời kho ${mine.warehouseName} cho đơn ${mine.orderCode}. Tồn thực tế và lượng giữ giảm cùng lúc. Bấm lại lần nữa sẽ không trừ thêm.',
      confirmLabel: 'Xác nhận xuất',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      final issued = await ref
          .read(warehouseRepositoryProvider)
          .confirmIssue(mine.id, version: mine.version);
      ref.invalidate(orderIssueProvider(widget.orderId));
      ref.invalidate(pickingDetailProvider(widget.sheet.pickingCode));
      ref.read(dataVersionProvider.notifier).state++;
      if (context.mounted) {
        showAppSnack(
          context,
          issued.issuedAt == null
              ? 'Đã xuất ${issued.shipmentCode} · ${issued.status.label}.'
              : 'Đã xuất ${issued.shipmentCode} lúc ${AppDates.timeDay(issued.issuedAt)}.',
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
