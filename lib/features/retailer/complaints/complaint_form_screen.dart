import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/data/models/complaint.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/repositories/loyalty_repository.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';

class ComplaintFormScreen extends ConsumerStatefulWidget {
  const ComplaintFormScreen({super.key, this.orderCode});
  final String? orderCode;
  @override
  ConsumerState<ComplaintFormScreen> createState() =>
      _ComplaintFormScreenState();
}

class _ComplaintFormScreenState extends ConsumerState<ComplaintFormScreen> {
  String? _orderCode, _allocationId;
  String _issueType = 'Shortage';
  final _actual = TextEditingController(), _note = TextEditingController();
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _orderCode = widget.orderCode;
  }

  @override
  void dispose() {
    _actual.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit(Order order, ComplaintTarget target) async {
    final actual = int.tryParse(_actual.text.trim());
    if (actual == null || actual < 0 || actual >= target.expectedQuantity) {
      showAppSnack(context,
          'Số lượng dùng được phải từ 0 đến ${target.expectedQuantity - 1} thùng của phần giao đã chọn.',
          error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await ref.read(loyaltyRepositoryProvider).complain(
          NewComplaint(
              orderCode: order.code,
              sku: target.sku,
              labelCode: target.labelCode,
              actualQty: actual,
              issueType: _issueType,
              note: _note.text.trim(),
              shipmentId: target.shipmentId,
              allocationId: target.allocationId));
      ref.invalidate(complaintsProvider);
      ref.invalidate(complaintTargetsProvider(order.id));
      if (!mounted) return;
      showAppSnack(context, 'Đã gửi khiếu nại ${result.code}.');
      context.pop();
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Tạo khiếu nại')),
      body: AsyncBody<OrderListResult>(
          value: ref.watch(ordersProvider),
          onRetry: () => ref.invalidate(ordersProvider),
          builder: (result) {
            // The list API returns summaries. Receipt targets supply the actual SKU/batch/shipment.
            final eligible = result.orders
                .where((o) =>
                    o.code.isNotEmpty &&
                    [
                      OrderStatus.delivering,
                      OrderStatus.delivered,
                      OrderStatus.completed
                    ].contains(o.status))
                .toList();
            final matches = eligible.where((o) => o.code == _orderCode);
            final order = matches.isEmpty ? null : matches.first;
            return ListView(padding: const EdgeInsets.all(16), children: [
              DropdownButtonFormField<String>(
                  key: ValueKey(_orderCode),
                  initialValue: order?.code,
                  decoration: const InputDecoration(
                      labelText: 'Đơn đã giao / đang nhận hàng'),
                  items: eligible
                      .map((o) =>
                          DropdownMenuItem(value: o.code, child: Text(o.code)))
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (v) => setState(() {
                            _orderCode = v;
                            _allocationId = null;
                            _actual.clear();
                          })),
              if (eligible.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Chưa có đơn đã giao để khiếu nại.')),
              if (order != null)
                ref.watch(complaintTargetsProvider(order.id)).when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, s) => TextButton(
                        onPressed: () =>
                            ref.invalidate(complaintTargetsProvider(order.id)),
                        child: const Text('Không tải được phần hàng. Thử lại')),
                    data: (targets) {
                      final chosen =
                          targets.where((t) => t.allocationId == _allocationId);
                      final target = chosen.isEmpty ? null : chosen.first;
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (targets.isEmpty)
                              const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text(
                                      'Không còn phần hàng đã nhận đủ điều kiện khiếu nại.')),
                            DropdownButtonFormField<String>(
                                key: ValueKey('${order.id}:$_allocationId'),
                                initialValue: target?.allocationId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                    labelText: 'Sản phẩm · batch · phần giao'),
                                items: targets
                                    .map((t) => DropdownMenuItem(
                                        value: t.allocationId,
                                        child: Text(
                                            '${t.sku} · ${t.batchCode} · ${t.shipmentCode}',
                                            overflow: TextOverflow.ellipsis)))
                                    .toList(),
                                onChanged: _busy
                                    ? null
                                    : (v) => setState(() {
                                          _allocationId = v;
                                          _actual.clear();
                                        })),
                            if (target != null) ...[
                              Text(
                                  '${target.productName}\nTem ${target.labelCode} · giao ${target.expectedQuantity} thùng'),
                              DropdownButtonFormField<String>(
                                  initialValue: _issueType,
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'Shortage',
                                        child: Text('Thiếu hàng')),
                                    DropdownMenuItem(
                                        value: 'Damaged',
                                        child: Text(
                                            'Hàng hỏng / không sử dụng được'))
                                  ],
                                  onChanged: _busy
                                      ? null
                                      : (v) => setState(
                                          () => _issueType = v ?? 'Shortage')),
                              TextField(
                                  controller: _actual,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText:
                                          'Số thùng dùng được trong phần giao này')),
                              TextField(
                                  controller: _note,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                      labelText: 'Mô tả thiếu / hư hỏng')),
                              const SizedBox(height: 16),
                              FilledButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _submit(order, target),
                                  child: Text(
                                      _busy ? 'Đang gửi...' : 'Gửi khiếu nại')),
                            ],
                          ]);
                    }),
            ]);
          }));
}
