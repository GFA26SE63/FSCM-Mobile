import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/product.dart';
import 'package:fscm_mobile/data/models/promotion.dart';
import 'package:fscm_mobile/data/repositories/catalog_repository.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/chip_filter_bar.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';

/// Product list with price, cached stock and the promotions that apply.
class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  String _query = '';
  String _category = '';

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Sản phẩm')),
      body: AsyncBody<CatalogData>(
        value: catalog,
        onRetry: () => ref.invalidate(catalogProvider),
        builder: (data) {
          final categories =
              data.products.map((p) => p.category).toSet().toList();
          final list = data.products.where((p) {
            if (_category.isNotEmpty && p.category != _category) return false;
            if (_query.isEmpty) return true;
            return p.name.toLowerCase().contains(_query) ||
                p.sku.toLowerCase().contains(_query);
          }).toList();
          final running = data.runningPromotions();
          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Tìm sản phẩm hoặc mã SKU',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                ),
              ),
              ChipFilterBar<String>(
                options: <ChipOption<String>>[
                  const ChipOption<String>('', 'Tất cả'),
                  for (final c in categories) ChipOption<String>(c, c),
                ],
                selected: _category,
                onSelected: (v) => setState(() => _category = v),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    InfoBanner(
                      text:
                          'Tồn khả dụng cập nhật lúc ${AppDates.timeDay(data.lastSyncAt)}. '
                          'Đặt tối đa = tồn khả dụng trừ tồn đệm an toàn, làm tròn xuống bội số 10.',
                    ),
                    for (final p in list) _tile(p, data, running),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(Product p, CatalogData data, List<Promotion> running) {
    final promos = running.where((pr) => _touches(pr, p.sku)).toList();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('${p.sku} · ${p.name}',
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 2),
          Text('${p.pack} · ${p.category}',
              style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Text('${Money.format(data.unitPrice(p.sku))} / thùng',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: AppColors.primary)),
              const Spacer(),
              Text(
                'Còn ${data.available(p.sku)} · tối đa ${data.maxQty(p.sku)}',
                style: TextStyle(
                    color: data.maxQty(p.sku) == 0
                        ? AppColors.danger
                        : AppColors.textMuted),
              ),
            ],
          ),
          if (promos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: <Widget>[
                  for (final pr in promos)
                    StatusChip(
                        label: '${pr.id} · ${_hint(pr, p.sku)}',
                        tone: StatusTone.warning),
                ],
              ),
            ),
        ],
      ),
    );
  }

  bool _touches(Promotion pr, String sku) => pr.type == 1
      ? pr.rules.any((r) => r.sku == sku)
      : pr.groupSkus.contains(sku);

  String _hint(Promotion pr, String sku) {
    if (pr.type == 1) {
      final r = pr.rules.firstWhere((x) => x.sku == sku);
      return 'từ ${r.minQty} thùng −${_pct(r.pct)}%';
    }
    return 'nhóm từ ${pr.groupMinQty} thùng −${_pct(pr.groupPct)}%';
  }

  String _pct(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();
}
