import 'package:flutter/material.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/data/models/performance.dart';
import 'package:fscm_mobile/features/sales/kpi/widgets/report_body.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/kv_row.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';

class SalesRankingContent extends StatelessWidget {
  const SalesRankingContent(
      {super.key, required this.report, required this.userId});
  final PerformanceReport<RankingEntry> report;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final mine = report.entries.where((entry) => entry.salesUserId == userId);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ReportHeader(report: report),
      const SectionTitle('Bảng xếp hạng Sales'),
      const Text('Theo doanh thu ghi nhận sau khuyến mãi và điều chỉnh.'),
      if (mine.isEmpty)
        const AppCard(
            child: Text('Bạn chưa có thứ hạng được ghi nhận trong kỳ này.')),
      for (final entry in mine)
        AppCard(
            color: AppColors.primarySoft,
            child: Text('Vị trí của bạn · ${entry.group}: #${entry.rank}',
                style: const TextStyle(fontWeight: FontWeight.w700))),
      if (report.entries.isEmpty)
        const Text('Chưa có dữ liệu xếp hạng trong phạm vi được cấp quyền.'),
      for (final entry in report.entries)
        AppCard(
          color: entry.salesUserId == userId ? AppColors.primarySoft : null,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                '#${entry.rank} · ${entry.name}${entry.salesUserId == userId ? ' (bạn)' : ''}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(entry.group),
            KvRow('Số đơn', '${entry.orderCount}'),
            KvRow('Doanh thu ghi nhận', Money.format(entry.recognizedRevenue)),
          ]),
        ),
    ]);
  }
}

class ProductRankingContent extends StatelessWidget {
  const ProductRankingContent({super.key, required this.report});
  final PerformanceReport<ProductRanking> report;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReportHeader(report: report),
          const SectionTitle('Sản phẩm bán chạy'),
          const Text(
              'Sản phẩm trong nhóm được cấp quyền; không phải chỉ riêng đơn của bạn.'),
          if (report.entries.isEmpty)
            const AppCard(
                child: Text('Chưa có sản phẩm được ghi nhận trong kỳ này.')),
          for (final entry in report.entries)
            AppCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('#${entry.rank} · ${entry.sku} · ${entry.name}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  KvRow('Số lượng',
                      '${reportValue(entry.quantity)} ${entry.unit == 'carton' ? 'thùng' : entry.unit}'),
                  KvRow('Doanh thu sau điều chỉnh',
                      Money.format(entry.adjustedNetRevenue)),
                ])),
        ],
      );
}
