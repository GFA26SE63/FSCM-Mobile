import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fscm_mobile/core/utils/clock.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/loyalty.dart';
import 'package:fscm_mobile/shared/widgets/chip_filter_bar.dart';
import 'package:fscm_mobile/data/repositories/loyalty_repository.dart';
import 'package:fscm_mobile/features/retailer/loyalty/widgets/loyalty_balance_card.dart';
import 'package:fscm_mobile/features/retailer/loyalty/widgets/loyalty_ledger_tile.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';

class LoyaltyScreen extends ConsumerWidget {
  const LoyaltyScreen({super.key});

  Future<void> _reload(WidgetRef ref) async {
    ref.invalidate(loyaltyAccountProvider);
    try {
      await ref.read(loyaltyAccountProvider.future);
    } catch (_) {
      // AsyncBody renders the provider error; no successful empty fallback.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(loyaltyAccountProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Thẻ tích điểm'), actions: [
        IconButton(
            tooltip: 'Tải lại thẻ tích điểm',
            onPressed: value.isLoading ? null : () => unawaited(_reload(ref)),
            icon: const Icon(Icons.refresh)),
      ]),
      body: AsyncBody<LoyaltyAccount>(
        value: value,
        onRetry: () => unawaited(_reload(ref)),
        builder: (account) => RefreshIndicator(
          onRefresh: () => _reload(ref),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              LoyaltyBalanceCard(account: account),
              FilledButton.icon(
                onPressed: () => context.push(AppRoutes.rtGifts),
                icon: const Icon(Icons.card_giftcard),
                label: Text(account.hasNegativeBalance
                    ? 'Xem quà & yêu cầu đã gửi'
                    : 'Đổi quà'),
              ),
              // The program (rate, validity, expiry) sits right under the balance
              // so it is found without scrolling through the history.
              const SectionTitle('Chương trình tích điểm'),
              LoyaltyProgramCard(account: account),
              LoyaltyLedgerSection(ledger: account.ledger),
            ],
          ),
        ),
      ),
    );
  }
}

enum _LedgerGroup { all, credit, redeem, pending, other }

enum _LedgerSpan { all, week, month }

/// Visible rows per step of the point history (the ledger itself arrives whole
/// from the card endpoint, so filtering here is exact).
const int ledgerPageSize = 10;

/// "Lịch sử điểm": filters by transaction type and period, shown 10 at a time.
class LoyaltyLedgerSection extends StatefulWidget {
  const LoyaltyLedgerSection({super.key, required this.ledger});
  final List<PointLedgerEntry> ledger;

  @override
  State<LoyaltyLedgerSection> createState() => _LoyaltyLedgerSectionState();
}

class _LoyaltyLedgerSectionState extends State<LoyaltyLedgerSection> {
  _LedgerGroup _group = _LedgerGroup.all;
  _LedgerSpan _span = _LedgerSpan.all;
  int _visible = ledgerPageSize;

  bool _inGroup(PointKind k) => switch (_group) {
        _LedgerGroup.all => true,
        _LedgerGroup.credit => k == PointKind.earned || k == PointKind.refunded,
        _LedgerGroup.redeem => k == PointKind.redeemed || k == PointKind.held,
        _LedgerGroup.pending =>
          k == PointKind.pending || k == PointKind.pendingCancelled,
        _LedgerGroup.other => k == PointKind.adjusted ||
            k == PointKind.expired ||
            k == PointKind.unknown,
      };

  bool _inSpan(DateTime d) => switch (_span) {
        _LedgerSpan.all => true,
        _LedgerSpan.week => AppDates.vietnamDaysBetween(d, AppClock.now()) <= 7,
        _LedgerSpan.month =>
          AppDates.vietnamDaysBetween(d, AppClock.now()) <= 30,
      };

  @override
  Widget build(BuildContext context) {
    final filtered = widget.ledger
        .where((e) => _inGroup(e.kind) && _inSpan(e.date))
        .toList();
    final shown = filtered.take(_visible).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle('Lịch sử điểm'),
      if (widget.ledger.isNotEmpty) ...[
        ChipFilterBar<_LedgerGroup>(
          padding: EdgeInsets.zero,
          selected: _group,
          onSelected: (v) => setState(() {
            _group = v;
            _visible = ledgerPageSize;
          }),
          options: const [
            ChipOption(_LedgerGroup.all, 'Tất cả'),
            ChipOption(_LedgerGroup.credit, 'Cộng / hoàn'),
            ChipOption(_LedgerGroup.redeem, 'Đã đổi quà'),
            ChipOption(_LedgerGroup.pending, 'Chờ cộng'),
            ChipOption(_LedgerGroup.other, 'Khác'),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ChipFilterBar<_LedgerSpan>(
          padding: EdgeInsets.zero,
          selected: _span,
          onSelected: (v) => setState(() {
            _span = v;
            _visible = ledgerPageSize;
          }),
          options: const [
            ChipOption(_LedgerSpan.all, 'Mọi lúc'),
            ChipOption(_LedgerSpan.week, '7 ngày'),
            ChipOption(_LedgerSpan.month, '30 ngày'),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
      if (widget.ledger.isEmpty)
        const AppCard(
            child: Column(children: [
          Icon(Icons.history, size: 32, color: AppColors.textMuted),
          SizedBox(height: AppSpacing.sm),
          Text('Chưa có giao dịch điểm.', style: AppText.muted),
        ]))
      else if (filtered.isEmpty)
        const AppCard(
            child: Text('Không có giao dịch phù hợp bộ lọc.',
                style: AppText.muted))
      else ...[
        for (final entry in shown)
          LoyaltyLedgerTile(key: ValueKey(entry.id), entry: entry),
        if (filtered.length > shown.length)
          OutlinedButton(
              onPressed: () => setState(() => _visible += ledgerPageSize),
              child: Text(
                  'Xem thêm (${shown.length}/${filtered.length} giao dịch)')),
      ],
    ]);
  }
}
