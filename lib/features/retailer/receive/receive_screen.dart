import 'package:fscm_mobile/core/utils/numbers.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/id_format.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/local/receipt_draft_store.dart';
import 'package:fscm_mobile/data/models/delivery_shipment.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/qr_scan_view.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';

/// A multi-warehouse order is received one shipment at a time. The retailer
/// explicitly chooses the warehouse part before scanning labels, preventing
/// labels from being submitted to the first Delivering shipment by accident.
class RtReceiveScreen extends ConsumerStatefulWidget {
  const RtReceiveScreen(
      {super.key, required this.code, this.initialShipmentId});

  final String code;

  /// Warehouse part tapped on the order; falls back to the first one.
  final String? initialShipmentId;

  @override
  ConsumerState<RtReceiveScreen> createState() => _RtReceiveScreenState();
}

class _RtReceiveScreenState extends ConsumerState<RtReceiveScreen> {
  final Set<String> _scanned = <String>{};
  late String? _selectedShipmentId = widget.initialShipmentId;

  /// Keeps one camera session while widgets above it come and go; a rebuilt
  /// scanner starts before the old one releases the camera and fails.
  final GlobalKey _scannerKey = GlobalKey();
  String _error = '';
  bool _busy = false;
  Order? _result;

  /// Shipment currently on screen; scanned codes are saved as its draft.
  DeliveryShipment? _current;
  String? _draftLoadedFor;
  int _restoredCount = 0;

  /// Codes survive leaving the screen: restore this shipment's draft once.
  void _ensureDraft(DeliveryShipment shipment) {
    _current = shipment;
    if (_draftLoadedFor == shipment.id) return;
    _draftLoadedFor = shipment.id;
    ref.read(receiptDraftStoreProvider).read(shipment).then((codes) {
      if (!mounted || _draftLoadedFor != shipment.id || codes.isEmpty) return;
      setState(() {
        _scanned.addAll(codes);
        _restoredCount = codes.length;
      });
    });
  }

  void _saveDraft() {
    final shipment = _current;
    if (shipment == null) return;
    unawaited(ref.read(receiptDraftStoreProvider).save(shipment, _scanned));
  }

  void _restart() {
    final shipment = _current;
    setState(() {
      _scanned.clear();
      _restoredCount = 0;
      _error = '';
    });
    if (shipment != null) {
      unawaited(ref.read(receiptDraftStoreProvider).clear(shipment.id));
    }
  }

  Future<void> _confirmLeave() async {
    final total = _current?.totalQuantity;
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title:
            const Text('Chưa xác nhận nhận hàng', textAlign: TextAlign.center),
        content: Text(
          total == null
              ? 'Bạn đã quét ${_scanned.length} thùng. Lưu nháp để lần sau quét tiếp từ chỗ đang dừng.'
              : 'Bạn đã quét ${_scanned.length}/${_quantity(total)} thùng. Lưu nháp để lần sau quét tiếp từ chỗ đang dừng.',
          textAlign: TextAlign.center,
          style: AppText.muted.copyWith(height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl, 0, AppSpacing.xxl, AppSpacing.xl),
        actions: <Widget>[
          SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop('keep'),
                  child: const Text('Lưu nháp và thoát'),
                ),
                const SizedBox(height: AppSpacing.s10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.dangerBorder),
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop('discard'),
                  child: const Text('Bỏ các thùng đã quét'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    // Codes are saved after every scan, so keeping them needs no extra write.
    if (choice == 'discard') _restart();
    setState(() => _scanned.clear());
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _confirm(Order order, DeliveryShipment shipment) async {
    final scannedCount = _scanned.length;
    if (scannedCount < shipment.totalQuantity) {
      final shortBy = shipment.totalQuantity - scannedCount;
      final ok = await confirmDialog(
        context,
        title: 'Phần giao đang thiếu thùng',
        message:
            'Bạn mới quét $scannedCount/${_quantity(shipment.totalQuantity)} thùng '
            '(thiếu ${_quantity(shortBy)} thùng). Hệ thống sẽ ghi nhận số thực nhận '
            'và đánh dấu phần thiếu để đối soát. Tiếp tục xác nhận?',
        confirmLabel: 'Xác nhận nhận thiếu',
        cancelLabel: 'Quét tiếp',
      );
      if (!ok || !mounted) return;
    }
    final receivedQuantities = _receivedQuantitiesFor(shipment);
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final result =
          await ref.read(orderRepositoryProvider).confirmShipmentReceipt(
                order.id,
                shipment,
                labelCodes: _scanned.toList(growable: false),
                receivedQuantities: receivedQuantities,
              );
      await ref.read(receiptDraftStoreProvider).clear(shipment.id);
      ref.invalidate(orderDetailProvider(widget.code));
      ref.invalidate(orderDetailProvider(order.id));
      ref.invalidate(deliveryShipmentsProvider(order.id));
      ref.read(dataVersionProvider.notifier).state++;
      if (mounted) {
        final totalReceived = receivedQuantities.values
            .fold<double>(0, (sum, value) => sum + value);
        final missing = (shipment.totalQuantity - totalReceived)
            .clamp(0, shipment.totalQuantity)
            .toDouble();
        setState(() {
          _result = result;
          _scanned.clear();
          _restoredCount = 0;
          _selectedShipmentId = null;
          _draftLoadedFor = null;
        });
        if (missing > 0) {
          final wantComplain = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Ghi nhận thiếu hàng'),
              content: Text(
                'Đã ghi nhận nhận ${_quantity(totalReceived)} / ${_quantity(shipment.totalQuantity)} thùng '
                '(thiếu ${_quantity(missing)} thùng).\n\n'
                'Bạn có muốn tạo phiếu khiếu nại ngay không?',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Để sau'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Tạo khiếu nại ngay'),
                ),
              ],
            ),
          );
          if (wantComplain == true && mounted) {
            await context.push(AppRoutes.rtComplaintFor(
              order.code,
              shipmentId: shipment.id,
            ));
          }
        }
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _selectShipment(String shipmentId) {
    if (_selectedShipmentId == shipmentId) return;
    // The previous part's codes are already saved as its draft.
    setState(() {
      _selectedShipmentId = shipmentId;
      _scanned.clear();
      _restoredCount = 0;
      _draftLoadedFor = null;
      _error = '';
    });
  }

  void _onScan(String raw) {
    final code = raw.trim().toUpperCase();
    final problem = IdFormat.cartonScanError(code);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    if (_scanned.contains(code)) {
      setState(() => _error = 'Mã thùng $code đã được quét.');
      return;
    }
    setState(() {
      _scanned.add(code);
      _error = '';
    });
    _saveDraft();
  }

  Map<String, double> _receivedQuantitiesFor(DeliveryShipment shipment) {
    var remaining = _scanned.length.toDouble();
    final result = <String, double>{};
    for (final line in shipment.lines) {
      final key = '${line.orderLineId}:${line.batchId}';
      final assigned = remaining.clamp(0, line.quantity).toDouble();
      result[key] = assigned;
      remaining -= assigned;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final orderValue = ref.watch(orderDetailProvider(widget.code));
    return PopScope(
      canPop: _scanned.isEmpty || _busy || _result != null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmLeave());
      },
      child: Scaffold(
        // Route param may be the order GUID; show the order code once loaded.
        appBar: AppBar(
            title: Text((orderValue.valueOrNull?.code.isNotEmpty ?? false)
                ? 'Nhận hàng · ${orderValue.valueOrNull!.code}'
                : 'Nhận hàng')),
        body: AsyncBody<Order>(
          value: orderValue,
          onRetry: () => ref.invalidate(orderDetailProvider(widget.code)),
          builder: (order) {
            if (_result != null) return _done(_result!);
            // Gate per part below: a part can be Delivering before the order is.
            if (!order.status.mayHavePartInDelivery) return _notReady(order);

            final shipmentsValue =
                ref.watch(deliveryShipmentsProvider(order.id));
            return AsyncBody<List<DeliveryShipment>>(
              value: shipmentsValue,
              onRetry: () =>
                  ref.invalidate(deliveryShipmentsProvider(order.id)),
              builder: (allShipments) => _receive(order, allShipments),
            );
          },
        ),
      ),
    );
  }

  Widget _notReady(Order order) => ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          InfoBanner(
            icon: Icons.info_outline,
            text:
                'Đơn ${order.code} đang ở trạng thái "${order.status.label}" nên chưa thể xác nhận nhận hàng.',
          ),
          OutlinedButton(
              onPressed: () => context.pop(), child: const Text('Quay lại')),
        ],
      );

  Widget _receive(Order order, List<DeliveryShipment> allShipments) {
    final shipments = allShipments.where((item) => item.canReceive).toList();
    if (shipments.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: const <Widget>[
          InfoBanner(
            icon: Icons.info_outline,
            text: 'Chưa có phần giao nào đang vận chuyển để xác nhận.',
          ),
        ],
      );
    }

    DeliveryShipment selected = shipments.first;
    for (final item in shipments) {
      if (item.id == _selectedShipmentId) selected = item;
    }
    _ensureDraft(selected);
    final ready = _scanned.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        InfoBanner(
          icon: Icons.local_shipping_outlined,
          text: shipments.length == 1
              ? 'Xác nhận riêng phần giao từ ${selected.warehouseName}.'
              : 'Đơn có ${shipments.length} phần giao đang tới. Chọn đúng kho trên phiếu giao trước khi quét thùng hàng.',
        ),
        const SectionTitle('1. Chọn phần giao'),
        for (final shipment in shipments)
          // Option card (prototype shipment parts): selected = primary border.
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Material(
              color: shipment.id == selected.id
                  ? AppColors.primarySoft
                  : AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.controlAll,
                side: BorderSide(
                    color: shipment.id == selected.id
                        ? AppColors.primary
                        : AppColors.border,
                    width: shipment.id == selected.id ? 1.5 : 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: RadioListTile<String>(
                value: shipment.id,
                groupValue: selected.id,
                onChanged: (value) {
                  if (value != null) _selectShipment(value);
                },
                title: Text('${shipment.warehouseName} · ${shipment.code}'),
                subtitle: Text(
                  '${shipment.warehouseCode} · ${_quantity(shipment.totalQuantity)} sản phẩm · '
                  '${shipment.lines.map((line) => line.sku).toSet().join(', ')}',
                ),
              ),
            ),
          ),
        SectionTitle('2. Quét mã thùng (CID) của ${selected.warehouseCode}'),
        InfoBanner(
          icon: Icons.qr_code_scanner,
          text:
              'Quét mã QR trên từng thùng hàng. Phần giao này có ${_quantity(selected.totalQuantity)} thùng (nếu thiếu thùng, hệ thống sẽ ghi nhận thực nhận và đánh dấu phần thiếu để đối soát). Mã đã quét được lưu tạm theo từng phần giao cho tới khi xác nhận.',
        ),
        if (_restoredCount > 0) ...<Widget>[
          InfoBanner(
            icon: Icons.restore,
            text:
                'Đã khôi phục $_restoredCount/${_quantity(selected.totalQuantity)} thùng quét trước đó.',
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy ? null : _restart,
              child: const Text('Quét lại từ đầu'),
            ),
          ),
        ],
        QrScanView(
          key: _scannerKey,
          hint: 'Quét mã QR trên thùng hàng',
          onCode: _onScan,
          demoCodes: selected.demoQrCodes
              .where((c) => !_scanned.contains(c.trim().toUpperCase()))
              .toList(growable: false),
        ),
        if (_error.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          InfoBanner(
            tone: StatusTone.danger,
            icon: Icons.error_outline,
            text: _error,
          ),
        ],
        SectionTitle('Số thùng đã quét (${_scanned.length})'),
        for (final code in _scanned)
          AppCard(
            margin: const EdgeInsets.only(bottom: AppSpacing.s6),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.card, vertical: AppSpacing.s10),
            child: Row(
              children: <Widget>[
                const Icon(Icons.check_circle, color: AppColors.success),
                const SizedBox(width: AppSpacing.s10),
                Expanded(child: Text(code, style: AppText.strong)),
                IconButton(
                  tooltip: 'Xóa mã này',
                  onPressed: _busy
                      ? null
                      : () {
                          setState(() => _scanned.remove(code));
                          _saveDraft();
                        },
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton(
          onPressed: ready && !_busy ? () => _confirm(order, selected) : null,
          child: Text(_busy
              ? 'Đang xác nhận...'
              : 'Xác nhận phần giao ${selected.warehouseCode}'),
        ),
      ],
    );
  }

  Widget _done(Order order) {
    final complete = order.status == OrderStatus.delivered ||
        order.status == OrderStatus.completed;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        // Success hero (prototype RECEIVED): icon disc + title + message.
        const SizedBox(height: AppSpacing.xl),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.successSoft,
            ),
            child: const Icon(Icons.check_rounded,
                size: 40, color: AppColors.success),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Đã xác nhận một phần giao của ${order.code}',
            textAlign: TextAlign.center, style: AppText.display),
        const SizedBox(height: AppSpacing.sm),
        Text(
          complete
              ? 'Đã nhận đủ mọi phần giao. Công nợ bắt đầu tính hạn từ ngày nhận đủ hàng.'
              : 'Đơn vẫn chờ phần giao từ kho còn lại. Hãy xác nhận từng phần khi hàng tới.',
          textAlign: TextAlign.center,
          style: AppText.muted.copyWith(height: 1.5),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (!complete)
          FilledButton(
            onPressed: () => setState(() => _result = null),
            child: const Text('Xác nhận phần giao tiếp theo'),
          ),
        if (!complete) const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: () =>
              context.pushReplacement(AppRoutes.rtOrderDetail(order.id)),
          child: const Text('Xem đơn hàng'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.rtComplaintFor(order.code)),
          icon: const Icon(Icons.report_gmailerrorred_outlined),
          label: const Text('Hàng thiếu / hư hỏng? Gửi khiếu nại'),
        ),
        TextButton(
          onPressed: () => context.push(AppRoutes.rtLoyalty),
          child: const Text('Xem thẻ tích điểm'),
        ),
      ],
    );
  }

  String _quantity(double value) => formatQuantity(value);
}
