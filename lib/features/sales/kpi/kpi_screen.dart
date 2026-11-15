import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/data/models/performance.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/performance_repository.dart';
import 'package:fscm_mobile/features/sales/kpi/widgets/kpi_content.dart';
import 'package:fscm_mobile/features/sales/kpi/widgets/ranking_content.dart';
import 'package:fscm_mobile/features/sales/kpi/widgets/report_body.dart';
import 'package:fscm_mobile/shared/widgets/chip_filter_bar.dart';

class KpiScreen extends ConsumerStatefulWidget {
  const KpiScreen({super.key});
  @override
  ConsumerState<KpiScreen> createState() => _KpiScreenState();
}

class _KpiScreenState extends ConsumerState<KpiScreen> {
  String _period = 'month';
  String _criterion = 'Quantity';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null || user.role != UserRole.sales) {
      return Scaffold(
          appBar: AppBar(title: const Text('KPI của tôi')),
          body: const Center(child: Text('Chức năng dành cho Sales.')));
    }
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
            title: const Text('KPI & xếp hạng'),
            bottom: const TabBar(tabs: [
              Tab(text: 'KPI của tôi'),
              Tab(text: 'Xếp hạng'),
              Tab(text: 'Sản phẩm'),
            ])),
        body: Column(children: [
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ChipFilterBar<String>(
                  options: const [
                    ChipOption('today', 'Hôm nay'),
                    ChipOption('week', '7 ngày'),
                    ChipOption('month', 'Tháng này'),
                    ChipOption('lastMonth', 'Tháng trước'),
                    ChipOption('quarter', 'Quý này'),
                  ],
                  selected: _period,
                  onSelected: (value) => setState(() => _period = value))),
          Expanded(
              child: TabBarView(children: [
            ReportBody<SalesKpi>(
                value: ref.watch(salesKpiProvider(_period)),
                reload: () async {
                  ref.invalidate(salesKpiProvider(_period));
                  await ref.read(salesKpiProvider(_period).future);
                },
                builder: (report) => KpiContent(report: report)),
            ReportBody<PerformanceReport<RankingEntry>>(
                value: ref.watch(salesRankingProvider(_period)),
                reload: () async {
                  ref.invalidate(salesRankingProvider(_period));
                  await ref.read(salesRankingProvider(_period).future);
                },
                builder: (report) =>
                    SalesRankingContent(report: report, userId: user.id)),
            Column(children: [
              ChipFilterBar<String>(
                  options: const [
                    ChipOption('Quantity', 'Theo số lượng'),
                    ChipOption('Revenue', 'Theo doanh thu'),
                  ],
                  selected: _criterion,
                  onSelected: (value) => setState(() => _criterion = value)),
              Expanded(
                  child: ReportBody<PerformanceReport<ProductRanking>>(
                      value: ref
                          .watch(productRankingProvider((_period, _criterion))),
                      reload: () async {
                        ref.invalidate(
                            productRankingProvider((_period, _criterion)));
                        await ref.read(
                            productRankingProvider((_period, _criterion))
                                .future);
                      },
                      builder: (report) =>
                          ProductRankingContent(report: report))),
            ]),
          ])),
        ]),
      ),
    );
  }
}
