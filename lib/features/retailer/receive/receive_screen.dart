import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/id_format.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/delivery_shipment.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/remote/orders_api.dart';
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
  final Map<String, String> _received = <String, String>{};
  final Map<String, String> _damaged = <String, String>{};
  final Map<String, String> _operationKeys = <String, String>{};
  final TextEditingController _note = TextEditingController();
  String? _selectedShipmentId;
  String _error = '';
  bool _busy = false;
  Order? _result;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String _lineKey(DeliveryShipmentLine line) =>
      '${line.orderLineId}:${line.batchId}';

  void _prepareShipment(DeliveryShipment shipment) {
    for (final line in shipment.lines) {
      final key = _lineKey(line);
      _received.putIfAbsent(key, () => _quantity(line.quantity));
      _damaged.putIfAbsent(key, () => '0');
    }
    _operationKeys.putIfAbsent(shipment.id, () => const Uuid().v4());
  }

  double? _value(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  List<ShipmentReceiptLineInput>? _receiptLines(DeliveryShipment shipment) {
    final result = <ShipmentReceiptLineInput>[];
    for (final line in shipment.lines) {
      final key = _lineKey(line);
      final received = _value(_received[key] ?? '');
      final damaged = _value(_damaged[key] ?? '');
      if (received == null ||
          damaged == null ||
          received < 0 ||
          damaged < 0 ||
          damaged > received ||
          received > line.quantity) {
        setState(() =>
            _error = 'Mỗi batch phải thỏa 0 ≤ hỏng ≤ thực nhận ≤ đã xuất.');
        return null;
      }
      result.add(ShipmentReceiptLineInput(
        orderLineId: line.orderLineId,
        batchId: line.batchId,
        receivedQuantity: received,
        damagedQuantity: damaged,
      ));
    }
    return result;
  }

  Future<void> _confirm(Order order, DeliveryShipment shipment) async {
    final lines = _receiptLines(shipment);
    if (lines == null) return;
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
                lines: lines,
                operationKey: _operationKeys[shipment.id]!,
                note: _note.text,
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
          _note.clear();
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
      _note.clear();
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
    _prepareShipment(selected);
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
          text:
              'Chỉ quét tem thuộc phần giao đã chọn. Đổi sang kho khác sẽ xóa danh sách tem đang quét.',
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
                Text(code, style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        const SectionTitle('3. Kiểm đếm theo batch'),
        const InfoBanner(
          icon: Icons.calculate_outlined,
          text:
              'Nhập số thực nhận và số hỏng. Số thiếu chỉ là tạm tính trên app; máy chủ sẽ tính và ghi nhận kết quả cuối cùng.',
        ),
        for (final line in selected.lines) _lineInput(line),
        const SectionTitle('4. Ghi chú / bằng chứng'),
        TextField(
          controller: _note,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Ghi chú nhận hàng',
            hintText:
                'Mô tả thiếu, hư hỏng; có thể bổ sung ảnh trong khiếu nại.',
          ),
        ),
        const SizedBox(height: 8),
        const InfoBanner(
          icon: Icons.report_gmailerrorred_outlined,
          text:
              'Nếu có thiếu hoặc hư hỏng, sau khi xác nhận hãy gửi khiếu nại F62 kèm bằng chứng hình ảnh.',
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

  Widget _lineInput(DeliveryShipmentLine line) {
    final key = _lineKey(line);
    final received = _value(_received[key] ?? '') ?? 0;
    final missing =
        (line.quantity - received).clamp(0, line.quantity).toDouble();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
              '${line.sku}${line.productName.isEmpty ? '' : ' · ${line.productName}'}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          Text('Batch ${line.batchCode} · Đã xuất ${_quantity(line.quantity)}',
              style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 8),
          Row(children: <Widget>[
            Expanded(
              child: TextFormField(
                key: ValueKey('received-$key'),
                initialValue: _received[key],
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Thực nhận'),
                onChanged: (value) => setState(() => _received[key] = value),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                key: ValueKey('damaged-$key'),
                initialValue: _damaged[key],
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Hư hỏng'),
                onChanged: (value) => setState(() => _damaged[key] = value),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text('Thiếu (tạm tính): ${_quantity(missing)}',
              style: TextStyle(
                  color: missing > 0 ? AppColors.danger : AppColors.textMuted)),
        ],
      ),
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

  String _quantity(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}
