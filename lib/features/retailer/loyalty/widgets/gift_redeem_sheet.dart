import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fscm_mobile/data/models/loyalty.dart';
import 'package:fscm_mobile/shared/widgets/quantity_stepper.dart';

class GiftRedeemSheet extends StatefulWidget {
  const GiftRedeemSheet({super.key, required this.gift, required this.balance});
  final Gift gift;
  final int balance;
  @override
  State<GiftRedeemSheet> createState() => _GiftRedeemSheetState();
}

class _GiftRedeemSheetState extends State<GiftRedeemSheet> {
  int _quantity = 1;
  bool _valid = true;
  @override
  Widget build(BuildContext context) {
    final gift = widget.gift;
    final max = math.min(math.min(widget.balance ~/ gift.points, 2147483647 ~/ gift.points),
        gift.stock ?? 2147483647);
    return SafeArea(child: SingleChildScrollView(child: Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Đổi ${gift.name}', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Text('Điểm khả dụng: ${widget.balance}'),
        Text('${gift.points} điểm / quà'),
        const SizedBox(height: 16),
        Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12, runSpacing: 8, children: [const Text('Số lượng quà'),
          QuantityStepper(value: _quantity, min: 1, max: max < 1 ? 1 : max,
            editable: true, enabled: max >= 1, unit: 'quà',
            onChanged: (value) => setState(() => _quantity = value),
            onValidationChanged: (value) => setState(() => _valid = value)),
        ]),
        const SizedBox(height: 12),
        Text('Tổng điểm: ${_quantity * gift.points}', style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('Khi gửi, hệ thống giữ điểm và số lượng quà. Nếu bị từ chối, phần đã giữ sẽ được hoàn lại. Máy chủ kiểm tra lại điểm và quà lúc nhận yêu cầu.'),
        const SizedBox(height: 16),
        FilledButton(onPressed: _valid && _quantity <= max
            ? () => Navigator.pop(context, _quantity) : null, child: const Text('Gửi yêu cầu đổi quà')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
      ]))));
  }
}
