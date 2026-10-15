import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/data/models/performance.dart';
import 'package:fscm_mobile/data/repositories/performance_repository.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/chip_filter_bar.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/kv_row.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';

/// "Doanh số của tôi" + ranking after promotion + top products.
class KpiScreen extends ConsumerStatefulWidget {
  const KpiScreen({super.key});

  @override
  ConsumerState<KpiScreen> createState() => _KpiScreenState();
}

class _KpiScreenState extends ConsumerState<KpiScreen> {
  String _period = 'month';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Doanh số & xếp hạng'),
          bottom: const TabBar(
            labelColor: AppColors.primary,
            indicatorColor: AppColors.primary,
            tabs: <Widget>[
              Tab(text: 'Doanh số'),
              Tab(text: 'Xếp hạng'),
              Tab(text: 'Sản phẩm'),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[_kpiTab(), _rankingTab(), _productsTab()],
        ),
      ),
    );
  }

  Widget _periodBar() => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: ChipFilterBar<String>(
          options: const <ChipOption<String>>[
            ChipOption<String>('today', 'Hôm nay'),
            ChipOption<String>('week', '7 ngày'),
            ChipOption<String>('month', 'Tháng này'),
          ],
          selected: _period,
          onSelected: (v) => setState(() => _period = v),
        ),
      );

  Widget _kpiTab() {
    final value = ref.watch(salesKpiProvider(_period));
    return Column(
      children: <Widget>[
        _periodBar(),
        Expanded(
          child: AsyncBody<SalesKpi>(
            value: value,
            onRetry: () => ref.invalidate(salesKpiProvider(_period)),
            builder: (k) => ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(k.periodLabel,
                          style: const TextStyle(color: AppColors.textMuted)),
                      const SizedBox(height: 4),
                      Text(Money.format(k.revenueAfterPromo),
                          style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary)),
                      const Text('Doanh thu sau khuyến mãi',
                          style: TextStyle(color: AppColors.textMuted)),
                      if (k.target > 0) ...<Widget>[
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                            value: k.progress,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4)),
                        const SizedBox(height: 4),
                        Text(
                            '${(k.progress * 100).round()}% mục tiêu ${Money.short(k.target)}',
                            style: const TextStyle(
                                fontSize: 12.5, color: AppColors.textMuted)),
                      ],
                      const Divider(height: 24),
                      KvRow('Số đơn', '${k.orderCount}'),
                      KvRow('Doanh thu trước KM', Money.format(k.revenue)),
                      KvRow('Chênh lệch do KM', Money.minus(k.promoGap)),
                    ],
                  ),
                ),
                const InfoBanner(
                  text:
                      'Doanh số và xếp hạng tính theo doanh thu sau khuyến mãi (tiền retailer thực trả), không gồm đơn bị từ chối, đã hủy hoặc chưa đồng bộ.',
                ),
                const SectionTitle('Theo điểm bán'),
                if (k.byRetailer.isEmpty) const Text('Không có đơn phù hợp.'),
                for (final r in k.byRetailer)
                  AppCard(
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(r.retailerName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              Text('${r.orders} đơn',
                                  style: const TextStyle(
                                      color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                        Text(Money.format(r.revenueAfterPromo),
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _rankingTab() {
    final value = ref.watch(salesRankingProvider('month'));
    return AsyncBody<List<RankingEntry>>(
      value: value,
      onRetry: () => ref.invalidate(salesRankingProvider('month')),
      builder: (list) {
        final me = list.where((e) => e.isMe).toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            const Text('Bảng xếp hạng',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const Text('Tháng 9/2026 · doanh thu sau khuyến mãi',
                style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 10),
            if (me.isNotEmpty)
              AppCard(
                color: AppColors.primarySoft,
                child: Row(
                  children: <Widget>[
                    const Text('Vị trí của bạn',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('#${me.first.rank}',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary)),
                  ],
                ),
              ),
            for (final e in list)
              AppCard(
                color: e.isMe ? AppColors.primarySoft : null,
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 34,
                      child: Text('${e.rank}',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: e.rank <= 3
                                  ? AppColors.primary
                                  : AppColors.textMuted)),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(e.isMe ? '${e.name} (bạn)' : e.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                              'Nhóm ${e.group} · trước KM ${Money.short(e.revenue)}',
                              style: const TextStyle(
                                  fontSize: 12.5, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    Text(Money.short(e.revenueAfterPromo),
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            const InfoBanner(
              text:
                  'Xếp hạng theo doanh thu sau khuyến mãi để tách Sales tự bán với Sales dựa vào mã giảm. Kết quả dùng cho KPI cuối kỳ.',
            ),
          ],
        );
      },
    );
  }

  Widget _productsTab() {
    final value = ref.watch(productRankingProvider('month'));
    return AsyncBody<List<ProductRanking>>(
      value: value,
      onRetry: () => ref.invalidate(productRankingProvider('month')),
      builder: (list) => ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Text('Sản phẩm bán chạy',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const Text('Tháng 9 theo số thùng · doanh thu sau KM',
              style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 10),
          for (var i = 0; i < list.length; i++)
            AppCard(
              child: Row(
                children: <Widget>[
                  SizedBox(
                      width: 30,
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16))),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('${list[i].sku} · ${list[i].name}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        Text('${list[i].qty} thùng',
                            style: const TextStyle(color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  Text(Money.short(list[i].revenueAfterPromo),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
