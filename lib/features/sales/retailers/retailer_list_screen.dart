import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/data/models/retailer.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/catalog_repository.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';
import 'package:fscm_mobile/shared/widgets/empty_state.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/sync/sync_service.dart';

/// "Chọn điểm bán": retailers of the Sales' area. Retailers outside the
/// area are listed but locked (no order can be created for them).
class RetailerListScreen extends ConsumerStatefulWidget {
  const RetailerListScreen({super.key});

  @override
  ConsumerState<RetailerListScreen> createState() => _RetailerListScreenState();
}

class _RetailerListScreenState extends ConsumerState<RetailerListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final catalog = ref.watch(catalogProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn điểm bán')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Tìm theo tên hoặc mã 8 số',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: AsyncBody<CatalogData>(
              value: catalog,
              onRetry: () => ref.invalidate(catalogProvider),
              builder: (data) {
                if (data.retailers.isEmpty) {
                  return EmptyState(
                    icon: Icons.sync_problem,
                    title: 'Chưa có dữ liệu điểm bán trên máy',
                    message:
                        'Kết nối mạng và đồng bộ để tải điểm bán, sản phẩm, giá và khuyến mãi.',
                    action: FilledButton(
                      onPressed: () => ref
                          .read(syncServiceProvider.notifier)
                          .syncAll(manual: true),
                      child: const Text('Đồng bộ ngay'),
                    ),
                  );
                }
                final list = data.retailers.where((r) {
                  if (_query.isEmpty) return true;
                  return r.name.toLowerCase().contains(_query) ||
                      r.code.contains(_query);
                }).toList();
                final mine =
                    list.where((r) => r.areaCode == user?.areaCode).toList();
                final others =
                    list.where((r) => r.areaCode != user?.areaCode).toList();
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    InfoBanner(
                      text:
                          'Mã điểm bán gồm 8 chữ số, đồng bộ với mã khách hàng trên SAP. Điểm bán ngoài khu vực ${user?.areaName ?? ''} của nhóm bị khóa - không tạo được đơn trái vùng.',
                    ),
                    if (list.isEmpty)
                      const EmptyState(title: 'Không có điểm bán phù hợp.'),
                    for (final r in mine) _tile(context, r, locked: false),
                    for (final r in others) _tile(context, r, locked: true),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, Retailer r, {required bool locked}) {
    return AppCard(
      color: locked ? AppColors.background : null,
      onTap: () {
        if (locked) {
          showAppSnack(
            context,
            'Điểm bán ${r.code} thuộc khu vực ${r.areaName}, ngoài khu vực của bạn - không tạo được đơn.',
            error: true,
          );
          return;
        }
        context.push(AppRoutes.salesNewOrder(r.code));
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  r.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: locked ? AppColors.textMuted : AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text('Mã ${r.code} · ${r.areaName}',
                    style: const TextStyle(color: AppColors.textMuted)),
                Text(r.address,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12.5)),
                const SizedBox(height: 4),
                Text(
                  r.creditAllowed
                      ? 'Công nợ cho phép ${r.creditTerm} ngày · ${r.tier}'
                      : 'Không mua công nợ · ${r.tier}',
                  style:
                      const TextStyle(fontSize: 12.5, color: AppColors.primary),
                ),
              ],
            ),
          ),
          Icon(locked ? Icons.lock_outline : Icons.chevron_right,
              color: AppColors.textMuted),
        ],
      ),
    );
  }
}
