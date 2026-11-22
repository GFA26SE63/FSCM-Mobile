import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fscm_mobile/data/models/loyalty.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';
import 'package:fscm_mobile/shared/widgets/quantity_stepper.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';

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
    final max = math.min(
        math.min(widget.balance ~/ gift.points, 2147483647 ~/ gift.points),
        gift.stock ?? 2147483647);
    return SafeArea(
        child: SingleChildScrollView(
            child: Padding(
                padding: EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Đổi ${gift.name}', style: AppText.pageTitle),
                      const SizedBox(height: AppSpacing.md),
                      // Summary card (prototype "Đổi N điểm lấy …?").
                      AppCard(
                          margin: EdgeInsets.zero,
                          color: AppColors.warningSoft,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Điểm khả dụng: ${widget.balance}',
                                    style: AppText.bodyMedium
                                        .copyWith(color: AppColors.warning)),
                                Text('${gift.points} điểm / quà',
                                    style: AppText.strong
                                        .copyWith(color: AppColors.warning)),
                              ])),
                      const SizedBox(height: AppSpacing.lg),
                      Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: AppSpacing.md,
                          runSpacing: AppSpacing.sm,
                          children: [
                            const Text('Số lượng quà',
                                style: AppText.cardTitle),
                            QuantityStepper(
                                value: _quantity,
                                min: 1,
                                max: max < 1 ? 1 : max,
                                editable: true,
                                enabled: max >= 1,
                                unit: 'quà',
                                onChanged: (value) =>
                                    setState(() => _quantity = value),
                                onValidationChanged: (value) =>
                                    setState(() => _valid = value)),
                          ]),
                      const SizedBox(height: AppSpacing.md),
                      Text('Tổng điểm: ${_quantity * gift.points}',
                          style: AppText.strong),
                      if (widget.balance - _quantity * gift.points >= 0)
                        Text(
                            'Khả dụng còn lại: ${widget.balance - _quantity * gift.points}',
                            style: AppText.mutedSmall),
                      const SizedBox(height: AppSpacing.sm),
                      const InfoBanner(
                          text:
                              'Khi gửi, hệ thống giữ điểm và số lượng quà. Nếu bị từ chối, phần đã giữ sẽ được hoàn lại. Máy chủ kiểm tra lại điểm và quà lúc nhận yêu cầu.'),
                      const SizedBox(height: AppSpacing.xs),
                      FilledButton(
                          onPressed: _valid && _quantity <= max
                              ? () => Navigator.pop(context, _quantity)
                              : null,
                          child: const Text('Gửi yêu cầu đổi quà')),
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Hủy')),
                    ]))));
  }
}
