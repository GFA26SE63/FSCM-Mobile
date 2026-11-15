import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/data/models/performance.dart';
import 'package:fscm_mobile/features/sales/kpi/widgets/report_body.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/kv_row.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';

class KpiContent extends StatelessWidget {
  const KpiContent({super.key, required this.report});
  final SalesKpi report;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReportHeader(report: report),
          Text('Cấu hình #${report.configurationVersion} · hiệu lực '
              '${report.configurationEffectiveFrom}'),
          const InfoBanner(
              text: 'KPI và doanh thu do máy chủ tính từ đơn Completed, '
                  'sau khuyến mãi và điều chỉnh. Đơn chưa hoàn tất hoặc chưa gửi không được ghi nhận.'),
          if (report.entries.isEmpty)
            const AppCard(
                child: Text('Chưa có dữ liệu KPI của bạn trong kỳ này. '
                    'Không có dữ liệu không đồng nghĩa đã được giao mục tiêu bằng 0.')),
          for (final entry in report.entries) ...[
            const SectionTitle('Kết quả KPI của tôi'),
            AppCard(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.groupName,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                KvRow('Hoàn thành tổng thể',
                    reportPercent(entry.overallCompletionRate)),
                KvRow('Doanh thu ghi nhận',
                    Money.format(entry.recognizedRevenue)),
                KvRow('Số đơn đóng góp', '${entry.orders.length}'),
              ],
            )),
            for (final metric in entry.metrics) KpiMetricCard(metric: metric),
            RetailerRevenueList(orders: entry.orders),
            const SectionTitle('Đơn hàng đóng góp'),
            if (entry.orders.isEmpty)
              const Text('Chưa có đơn hàng được ghi nhận.'),
            for (final order in entry.orders)
              AppCard(
                onTap: () => context.push(AppRoutes.salesOrderDetail(order.id)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.code,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('${order.retailerName} · ${order.retailerCode}'),
                      KvRow('Ngày ghi nhận', order.recognitionDate),
                      KvRow('Trước khuyến mãi',
                          Money.format(order.revenueBeforePromotion)),
                      KvRow('Khuyến mãi', Money.minus(order.promotionAmount)),
                      KvRow('Sau khuyến mãi',
                          Money.format(order.revenueAfterPromotion)),
                      KvRow('Điều chỉnh được duyệt',
                          Money.format(order.adjustment)),
                      KvRow('Doanh thu ghi nhận',
                          Money.format(order.recognizedRevenue),
                          bold: true),
                      const Text('Mở chi tiết đơn hàng →'),
                    ]),
              ),
          ],
        ],
      );
}

class KpiMetricCard extends StatelessWidget {
  const KpiMetricCard({super.key, required this.metric});
  final KpiMetric metric;

  String _amount(num value) => metric.unit == 'ratio'
      ? reportPercent(value)
      : '${reportValue(value)} ${switch (metric.unit) {
          'order' => 'đơn',
          'retailer' => 'điểm bán',
          _ => metric.unit,
        }}';

  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(metric.name,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          KvRow(
              metric.code == 'promotionRevenueRatio'
                  ? 'Ngưỡng tối đa'
                  : 'Mục tiêu',
              _amount(metric.target)),
          KvRow('Thực đạt', _amount(metric.actual)),
          KvRow('Tỷ lệ hoàn thành', reportPercent(metric.completionRate)),
          LinearProgressIndicator(
              value: metric.completionRate.clamp(0, 1).toDouble()),
          KvRow('Trọng số', reportPercent(metric.weight)),
          KvRow('Điểm có trọng số', reportPercent(metric.weightedScore)),
        ]),
      );
}

/// Keeps the existing retailer breakdown, using the server's contributing orders.
class RetailerRevenueList extends StatelessWidget {
  const RetailerRevenueList({super.key, required this.orders});
  final List<KpiOrder> orders;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<KpiOrder>>{};
    for (final order in orders) {
      groups.putIfAbsent(order.retailerId, () => []).add(order);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle('Theo điểm bán'),
      if (groups.isEmpty) const Text('Không có đơn phù hợp.'),
      for (final rows in groups.values)
        AppCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${rows.first.retailerName} · ${rows.first.retailerCode}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          KvRow('Số đơn', '${rows.length}'),
          KvRow(
              'Trước khuyến mãi',
              Money.format(rows.fold<num>(
                  0, (sum, order) => sum + order.revenueBeforePromotion))),
          KvRow(
              'Khuyến mãi',
              Money.minus(rows.fold<num>(
                  0, (sum, order) => sum + order.promotionAmount))),
          KvRow(
              'Sau khuyến mãi',
              Money.format(rows.fold<num>(
                  0, (sum, order) => sum + order.revenueAfterPromotion))),
          KvRow(
              'Doanh thu ghi nhận',
              Money.format(rows.fold<num>(
                  0, (sum, order) => sum + order.recognizedRevenue))),
        ])),
    ]);
  }
}
