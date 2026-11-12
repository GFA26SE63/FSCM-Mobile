import 'package:flutter/material.dart';

import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';

/// F98: price of one order line split by the batch each part was allocated from.
///
/// Everything shown comes from the server snapshot taken when the quote was
/// issued. Nothing here is recomputed from current discount tables, and no
/// internal allocation data (MLOR, score, distance) is displayed.
class BatchPriceBreakdown extends StatelessWidget {
  const BatchPriceBreakdown({super.key, required this.batches});

  final List<BatchAllocation> batches;

  @override
  Widget build(BuildContext context) {
    if (batches.isEmpty) return const SizedBox.shrink();
    final priced = batches.where((b) => b.hasPriceSnapshot).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final batch in batches)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child:
                batch.hasPriceSnapshot ? _BatchCard(batch) : _PlainBatch(batch),
          ),
        if (priced.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Đơn này chưa có giá chi tiết theo batch.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
      ],
    );
  }
}

class _PlainBatch extends StatelessWidget {
  const _PlainBatch(this.batch);

  final BatchAllocation batch;

  @override
  Widget build(BuildContext context) => Text(
        '• ${batch.batchCode} · ${batch.qty} thùng'
        ' · HSD ${AppDates.date(batch.expiry)}'
        '${batch.warehouseName.isEmpty ? '' : ' · ${batch.warehouseName}'}',
        style: const TextStyle(
          fontSize: 12.5,
          color: AppColors.textMuted,
          height: 1.3,
        ),
      );
}

class _BatchCard extends StatelessWidget {
  const _BatchCard(this.batch);

  final BatchAllocation batch;

  @override
  Widget build(BuildContext context) {
    final hasShelfLifeDiscount = batch.shelfLifeDiscountPerUnit > 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${batch.batchCode} · ${batch.qty} thùng',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            [
              if (batch.warehouseName.isNotEmpty) 'Kho ${batch.warehouseName}',
              'HSD ${AppDates.date(batch.expiry)}',
              if (batch.estimatedArrivalAt != null)
                'Dự kiến tới ${AppDates.timeDay(batch.estimatedArrivalAt)}',
            ].join(' · '),
            style: const TextStyle(
                fontSize: 12, color: AppColors.textMuted, height: 1.3),
          ),
          const SizedBox(height: 6),
          _row('Giá niêm yết', Money.format(batch.listUnitPrice)),
          if (batch.promotionDiscountPerUnit > 0)
            _row('Giảm khuyến mãi / thùng',
                Money.minus(batch.promotionDiscountPerUnit),
                color: AppColors.success),
          _row('Giá sau khuyến mãi', Money.format(batch.baseUnitPrice)),
          _row('HSD còn lại khi giao',
              '${_pct(batch.remainingShelfLifePercent)}%'),
          _row(
            'Giảm theo HSD',
            hasShelfLifeDiscount
                ? '${_pct(batch.shelfLifeDiscountPercent)}% · '
                    '${Money.minus(batch.shelfLifeDiscountPerUnit)}'
                : 'Không giảm',
            color: hasShelfLifeDiscount ? AppColors.success : null,
          ),
          _row('Giá cuối / thùng', Money.format(batch.finalUnitPrice),
              bold: true),
          _row('Thành tiền', Money.format(batch.netAmount), bold: true),
          if (batch.discountReason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                batch.discountReason,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textMuted, height: 1.3),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? color, bool bold = false}) {
    final weight = bold ? FontWeight.w800 : FontWeight.w500;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(label,
                style:
                    const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          ),
          Text(value,
              style: TextStyle(fontSize: 13, fontWeight: weight, color: color)),
        ],
      ),
    );
  }

  static String _pct(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
}
