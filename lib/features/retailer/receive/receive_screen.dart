import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/id_format.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/delivery_shipment.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/qr_scan_view.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';

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
  final Set<String> _scanned = <String>{};
  String? _selectedShipmentId;
  String _error = '';
  bool _busy = false;
  Order? _result;

  Future<void> _confirm(Order order, DeliveryShipment shipment) async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final result = await ref
          .read(orderRepositoryProvider)
          .confirmShipmentReceipt(
            order.id,
            shipment,
            labelCodes: _scanned.toList(growable: false),
          );
      ref.invalidate(orderDetailProvider(widget.code));
      ref.invalidate(orderDetailProvider(order.id));
      ref.invalidate(deliveryShipmentsProvider(order.id));
      ref.read(dataVersionProvider.notifier).state++;
      if (mounted) {
        setState(() {
          _result = result;
          _scanned.clear();
          _selectedShipmentId = null;
        });
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
      _scanned.clear();
      _error = '';
    });
  }

  void _onScan(String raw) {
    final code = raw.trim().toUpperCase();
    if (!IdFormat.isLabel(code)) {
      setState(() => _error = 'Mã "$code" không phải tem hàng (TEM-000000).');
      return;
    }
    if (_scanned.contains(code)) {
      setState(() => _error = 'Tem $code đã quét rồi.');
      return;
    }
    setState(() {
      _scanned.add(code);
      _error = '';
    });
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
        padding: const EdgeInsets.all(16),
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
        padding: const EdgeInsets.all(16),
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
    final ready = _scanned.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        InfoBanner(
          icon: Icons.local_shipping_outlined,
          text: shipments.length == 1
              ? 'Xác nhận riêng phần giao từ ${selected.warehouseName}.'
              : 'Đơn có ${shipments.length} phần giao đang tới. Chọn đúng kho trên phiếu giao trước khi quét tem.',
        ),
        const SectionTitle('1. Chọn phần giao'),
        for (final shipment in shipments)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
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
        SectionTitle('2. Quét tem của ${selected.warehouseCode}'),
        const InfoBanner(
          icon: Icons.qr_code_scanner,
          text: 'Chỉ quét tem thuộc phần giao đã chọn. Đổi sang kho khác sẽ xóa danh sách tem đang quét.',
        ),
        QrScanView(
          hint: 'Quét tem trên kiện hàng',
          onCode: _onScan,
        ),
        if (_error.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          InfoBanner(
            tone: StatusTone.danger,
            icon: Icons.error_outline,
            text: _error,
          ),
        ],
        SectionTitle('Tem đã quét (${_scanned.length})'),
        for (final code in _scanned)
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: <Widget>[
                const Icon(Icons.check_circle, color: AppColors.primary),
                const SizedBox(width: 10),
                Text(code,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        const SizedBox(height: 4),
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
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        InfoBanner(
          tone: StatusTone.success,
          icon: Icons.check_circle_outline,
          title: 'Đã xác nhận một phần giao của ${order.code}',
          text: complete
              ? 'Đã nhận đủ mọi phần giao. Công nợ bắt đầu tính hạn từ ngày nhận đủ hàng.'
              : 'Đơn vẫn chờ phần giao từ kho còn lại. Hãy xác nhận từng phần khi hàng tới.',
        ),
        if (!complete)
          FilledButton(
            onPressed: () => setState(() => _result = null),
            child: const Text('Xác nhận phần giao tiếp theo'),
          ),
        if (!complete) const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () =>
              context.pushReplacement(AppRoutes.rtOrderDetail(order.id)),
          child: const Text('Xem đơn hàng'),
        ),
        const SizedBox(height: 8),
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

  String _quantity(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toString();
}
