import 'package:fscm_mobile/core/utils/numbers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/id_format.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/delivery_shipment.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/label_info.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/data/repositories/warehouse_repository.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/qr_scan_view.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';

/// A multi-warehouse order is received one shipment at a time. The retailer
/// explicitly chooses the warehouse part before scanning labels, preventing
/// labels from being submitted to the first Delivering shipment by accident.
class RtReceiveScreen extends ConsumerStatefulWidget {
  const RtReceiveScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<RtReceiveScreen> createState() => _RtReceiveScreenState();
}

class _RtReceiveScreenState extends ConsumerState<RtReceiveScreen> {
  final Map<String, LabelInfo> _scannedLabels = <String, LabelInfo>{};
  String? _selectedShipmentId;
  String _error = '';
  bool _busy = false;
  bool _lookingUp = false;
  Order? _result;

  Future<void> _confirm(
    Order order,
    DeliveryShipment shipment, {
    required Map<String, double> receivedQuantities,
    String? note,
  }) async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final result =
          await ref.read(orderRepositoryProvider).confirmShipmentReceipt(
                order.id,
                shipment,
                labelCodes: _scannedLabels.keys.toList(growable: false),
                receivedQuantities: receivedQuantities,
                note: note,
              );
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
          _scannedLabels.clear();
          _selectedShipmentId = null;
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
              actualQty: totalReceived.round(),
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
    setState(() {
      _selectedShipmentId = shipmentId;
      _scannedLabels.clear();
      _error = '';
    });
  }

  Future<void> _onScan(String raw, String orderCode) async {
    if (_busy || _lookingUp) return;
    final code = raw.trim().toUpperCase();
    if (!IdFormat.isCarton(code)) {
      setState(() => _error = 'Mã "$code" không phải mã thùng hàng CID hợp lệ.');
      return;
    }
    if (_scannedLabels.containsKey(code)) {
      setState(() => _error = 'Tem $code đã quét rồi.');
      return;
    }
    setState(() {
      _lookingUp = true;
      _error = '';
    });
    try {
      final label = await ref.read(warehouseRepositoryProvider).label(code);
      if (!mounted) return;
      if (label.orderCode.isNotEmpty && label.orderCode != orderCode) {
        setState(() => _error =
            'Tem $code thuộc đơn ${label.orderCode}, không thuộc đơn $orderCode.');
        return;
      }
      setState(() {
        _scannedLabels[code] = label;
        _error = '';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.statusCode == 403 || e.statusCode == 404
          ? 'Tem $code không thuộc đơn hàng của bạn.'
          : e.message);
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  Map<String, double> _receivedQuantitiesFor(DeliveryShipment shipment) {
    final result = <String, double>{};
    for (final line in shipment.lines) {
      final key = '${line.orderLineId}:${line.batchId}';
      var matchedQty = 0.0;
      for (final label in _scannedLabels.values) {
        if (label.sku == line.sku && label.batchCode == line.batchCode) {
          matchedQty += label.qty > 0 ? label.qty : 1;
        }
      }
      result[key] = matchedQty.clamp(0, line.quantity).toDouble();
    }
    return result;
  }

  Future<void> _handleConfirmTap(
    Order order,
    DeliveryShipment selected,
  ) async {
    final receivedMap = _receivedQuantitiesFor(selected);
    final totalReceived =
        receivedMap.values.fold<double>(0, (sum, value) => sum + value);
    final missing = (selected.totalQuantity - totalReceived)
        .clamp(0, selected.totalQuantity)
        .toDouble();

    if (missing <= 0) {
      await _confirm(order, selected, receivedQuantities: receivedMap);
      return;
    }

    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận nhận thiếu hàng'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Bạn mới quét ${_quantity(totalReceived)} / ${_quantity(selected.totalQuantity)} thùng '
              '(thiếu ${_quantity(missing)} thùng).\n\n'
              'Các tem đã quét sẽ chuyển trạng thái Đã giao; tem chưa quét sẽ được đánh dấu Thiếu khi giao để đối soát.',
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: noteController,
              maxLength: 500,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Ghi chú nhận thiếu (không bắt buộc)',
                hintText: 'VD: Xe giao thiếu 1 thùng',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Quay lại quét tiếp'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xác nhận nhận thiếu'),
          ),
        ],
      ),
    );
    final note = noteController.text;
    noteController.dispose();
    if (confirmed == true && mounted) {
      await _confirm(
        order,
        selected,
        receivedQuantities: receivedMap,
        note: note,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderValue = ref.watch(orderDetailProvider(widget.code));
    return Scaffold(
      appBar: AppBar(title: Text('Nhận hàng · ${widget.code}')),
      body: AsyncBody<Order>(
        value: orderValue,
        onRetry: () => ref.invalidate(orderDetailProvider(widget.code)),
        builder: (order) {
          if (_result != null) return _done(_result!);
          if (!order.status.canConfirmReceipt) return _notReady(order);

          final shipmentsValue = ref.watch(deliveryShipmentsProvider(order.id));
          return AsyncBody<List<DeliveryShipment>>(
            value: shipmentsValue,
            onRetry: () => ref.invalidate(deliveryShipmentsProvider(order.id)),
            builder: (allShipments) => _receive(order, allShipments),
          );
        },
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
    final ready = _scannedLabels.isNotEmpty;
    final scannedQty = _receivedQuantitiesFor(selected)
        .values
        .fold<double>(0, (sum, value) => sum + value);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        InfoBanner(
          icon: Icons.local_shipping_outlined,
          text: shipments.length == 1
              ? 'Xác nhận riêng phần giao từ ${selected.warehouseName}.'
              : 'Đơn có ${shipments.length} phần giao đang tới. Chọn đúng kho trên phiếu giao trước khi quét tem.',
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
        SectionTitle('2. Quét tem của ${selected.warehouseCode}'),
        const InfoBanner(
          icon: Icons.qr_code_scanner,
          text:
              'Chỉ quét tem thuộc phần giao đã chọn. Đổi sang kho khác sẽ xóa danh sách tem đang quét.',
        ),
        QrScanView(
          hint: 'Quét tem trên kiện hàng',
          onCode: (raw) => _onScan(raw, order.code),
        ),
        if (_error.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          InfoBanner(
            tone: StatusTone.danger,
            icon: Icons.error_outline,
            text: _error,
          ),
        ],
        SectionTitle(
            'Tem đã quét (${_quantity(scannedQty)} / ${_quantity(selected.totalQuantity)} thùng)'),
        for (final entry in _scannedLabels.entries)
          AppCard(
            margin: const EdgeInsets.only(bottom: AppSpacing.s6),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.card, vertical: AppSpacing.s10),
            child: Row(
              children: <Widget>[
                const Icon(Icons.check_circle, color: AppColors.success),
                const SizedBox(width: AppSpacing.s10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(entry.key, style: AppText.strong),
                      if (entry.value.sku.isNotEmpty)
                        Text(
                          '${entry.value.sku} · ${entry.value.batchCode} · ${entry.value.qty} thùng',
                          style: AppText.muted,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Xóa tem này',
                  onPressed: _busy
                      ? null
                      : () => setState(() => _scannedLabels.remove(entry.key)),
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton(
          onPressed: ready && !_busy && !_lookingUp
              ? () => _handleConfirmTap(order, selected)
              : null,
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
