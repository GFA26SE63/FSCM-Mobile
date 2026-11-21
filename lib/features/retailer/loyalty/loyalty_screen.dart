import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fscm_mobile/data/models/loyalty.dart';
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
              const SectionTitle('Lịch sử điểm'),
              if (account.ledger.isEmpty)
                const AppCard(
                    child: Column(children: [
                  Icon(Icons.history, size: 32, color: AppColors.textMuted),
                  SizedBox(height: AppSpacing.sm),
                  Text('Chưa có giao dịch điểm.', style: AppText.muted),
                ]))
              else
                for (final entry in account.ledger)
                  LoyaltyLedgerTile(key: ValueKey(entry.id), entry: entry),
              const SectionTitle('Chương trình tích điểm'),
              LoyaltyProgramCard(account: account),
            ],
          ),
        ),
      ),
    );
  }
}
