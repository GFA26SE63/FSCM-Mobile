import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/loyalty.dart';
import 'package:fscm_mobile/data/repositories/loyalty_repository.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';

/// Loyalty card: available / pending / held points, program rule and ledger.
class LoyaltyScreen extends ConsumerWidget {
  const LoyaltyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(loyaltyAccountProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Thẻ tích điểm')),
      body: AsyncBody<LoyaltyAccount>(
        value: value,
        onRetry: () => ref.invalidate(loyaltyAccountProvider),
        builder: (a) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(loyaltyAccountProvider),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${a.program.code} · ${a.program.name}',
                      style: const TextStyle(
                          color: Colors.white70, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${a.balance}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.w800),
                    ),
                    const Text('điểm khả dụng',
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        _mini('Chờ cộng', a.pending),
                        const SizedBox(width: 24),
                        _mini('Đang giữ', a.held),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Text(
                  'Cứ ${Money.format(a.program.amountPerPoint)} giá trị đơn hàng (sau khuyến mãi) được 1 điểm. '
                  'Điểm được cộng khi bạn quét QR nhận hàng; đơn công nợ cộng sau khi thanh toán đủ.'
                  '${a.program.expiryText.isEmpty ? '' : '\n${a.program.expiryText}'}',
                  style: const TextStyle(height: 1.4),
                ),
              ),
              if (a.balance < 0) ...<Widget>[
                const SizedBox(height: 12),
                const AppCard(
                  child: Text(
                    'Điểm khả dụng đang âm do có giao dịch điều chỉnh. Bạn chưa thể đổi quà mới cho đến khi số dư được xử lý.',
                    style: TextStyle(color: AppColors.danger, height: 1.4),
                  ),
                ),
              ],
              FilledButton.icon(
                onPressed: a.balance > 0 ? () => context.push(AppRoutes.rtGifts) : null,
                icon: const Icon(Icons.card_giftcard),
                label: const Text('Đổi quà'),
              ),
              const SectionTitle('Lịch sử điểm'),
              if (a.ledger.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Chưa có giao dịch điểm.'))
              else
                for (final e in a.ledger) _LedgerTile(entry: e),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mini(String label, int value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text('$value',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16)),
        ],
      );
}

class _LedgerTile extends StatelessWidget {
  const _LedgerTile({required this.entry});

  final PointLedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final negative = e.points < 0;
    final color = negative
        ? AppColors.danger
        : (e.kind == PointKind.pending
            ? AppColors.textMuted
            : AppColors.success);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(e.description,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${AppDates.timeDay(e.date)} · ${e.kind.label}'
                  '${e.source.isEmpty ? '' : ' · Nguồn: ${e.source}'}',
                  style:
                      const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '${negative ? '' : '+'}${e.points}',
            style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 16, color: color),
          ),
        ],
      ),
    );
  }
}
