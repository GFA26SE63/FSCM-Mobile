import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/data/models/complaint.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/repositories/loyalty_repository.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';

/// New complaint about a delivered order (missing / damaged goods).
/// [orderCode] pre-selects the order when opened from an order screen.
class ComplaintFormScreen extends ConsumerStatefulWidget {
  const ComplaintFormScreen({super.key, this.orderCode});

  final String? orderCode;

  @override
  ConsumerState<ComplaintFormScreen> createState() =>
      _ComplaintFormScreenState();
}

class _ComplaintFormScreenState extends ConsumerState<ComplaintFormScreen> {
  String? _orderCode;
  String? _sku;
  final TextEditingController _actual = TextEditingController();
  final TextEditingController _note = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _orderCode = (widget.orderCode ?? '').isEmpty ? null : widget.orderCode;
  }

  @override
  void dispose() {
    _actual.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit(Order order) async {
    final sku = _sku;
    final actual = int.tryParse(_actual.text.trim());
    if (sku == null) {
      showAppSnack(context, 'Chọn sản phẩm cần khiếu nại.', error: true);
      return;
    }
    if (actual == null || actual < 0) {
      showAppSnack(context, 'Nhập số lượng thực nhận (0 trở lên).',
          error: true);
      return;
    }
    final line = order.lines.firstWhere((l) => l.sku == sku);
    if (actual >= line.qty) {
      showAppSnack(context, 'Số thực nhận phải nhỏ hơn số đặt (${line.qty}).',
          error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final label = line.batches.isNotEmpty ? line.batches.first.labelCode : '';
      final c = await ref.read(loyaltyRepositoryProvider).complain(
            NewComplaint(
              orderCode: order.code,
              sku: sku,
              labelCode: label,
              actualQty: actual,
              note: _note.text.trim(),
            ),
          );
      ref.invalidate(complaintsProvider);
      if (!mounted) return;
      showAppSnack(context, 'Đã gửi khiếu nại ${c.code}.');
      context.pop();
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo khiếu nại')),
      body: AsyncBody<OrderListResult>(
        value: orders,
        onRetry: () => ref.invalidate(ordersProvider),
        builder: (result) {
          final eligible = result.orders
              .where((o) =>
                  !o.status.isActive && o.lines.isNotEmpty && o.code.isNotEmpty)
              .toList();
          final selected = eligible.where((o) => o.code == _orderCode).toList();
          final order = selected.isEmpty ? null : selected.first;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              const SectionTitle('Đơn hàng'),
              DropdownButtonFormField<String>(
                initialValue: order?.code,
                hint: const Text('Chọn đơn đã nhận'),
                items: <DropdownMenuItem<String>>[
                  for (final o in eligible)
                    DropdownMenuItem<String>(
                        value: o.code, child: Text(o.code)),
                ],
                onChanged: (v) => setState(() {
                  _orderCode = v;
                  _sku = null;
                }),
              ),
              if (order != null) ...<Widget>[
                const SectionTitle('Sản phẩm'),
                DropdownButtonFormField<String>(
                  initialValue: _sku,
                  hint: const Text('Chọn sản phẩm'),
                  isExpanded: true,
                  items: <DropdownMenuItem<String>>[
                    for (final l in order.lines)
                      DropdownMenuItem<String>(
                          value: l.sku,
                          child: Text('${l.sku} · ${l.name} (đặt ${l.qty})',
                              overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => _sku = v),
                ),
                const SectionTitle('Số lượng thực nhận'),
                TextField(
                  controller: _actual,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'Ví dụ: 55'),
                ),
                const SectionTitle('Ghi chú'),
                TextField(
                  controller: _note,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(hintText: 'Mô tả thiếu / hư hỏng'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : () => _submit(order),
                  child: Text(_busy ? 'Đang gửi...' : 'Gửi khiếu nại'),
                ),
              ] else if (eligible.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Chưa có đơn đã giao để khiếu nại.'),
                ),
            ],
          );
        },
      ),
    );
  }
}
