import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/data/models/loyalty.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';
import 'package:fscm_mobile/data/repositories/loyalty_repository.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';

/// Gift catalog + own redemption requests. Redeeming holds the points until
/// the request is processed (refunded if rejected).
class GiftsScreen extends ConsumerStatefulWidget {
  const GiftsScreen({super.key, this.redemptionId});
  final String? redemptionId;

  @override
  ConsumerState<GiftsScreen> createState() => _GiftsScreenState();
}

class _GiftsScreenState extends ConsumerState<GiftsScreen> {
  String _busyGift = '';

  Future<void> _redeem(Gift g) async {
    final state = ref.read(loyaltyAccountProvider);
    if (state.isLoading ||
        state.hasError ||
        state.valueOrNull == null ||
        state.requireValue.hasNegativeBalance ||
        state.requireValue.balance < g.points) {
      showAppSnack(context, 'Chưa đủ điểm khả dụng đã xác minh để đổi quà.',
          error: true);
      return;
    }
    final ok = await confirmDialog(
      context,
      title: 'Đổi quà',
      message:
          'Đổi "${g.name}" với ${g.points} điểm? Điểm sẽ được giữ cho đến khi yêu cầu được xử lý.',
      confirmLabel: 'Đổi quà',
    );
    if (!ok || !mounted) {
      return;
    }
    final latest = ref.read(loyaltyAccountProvider);
    if (latest.isLoading ||
        latest.hasError ||
        latest.valueOrNull == null ||
        latest.requireValue.hasNegativeBalance ||
        latest.requireValue.balance < g.points) {
      showAppSnack(
          context, 'Điểm khả dụng đã thay đổi. Hãy tải lại thẻ tích điểm.',
          error: true);
      return;
    }
    setState(() => _busyGift = g.code);
    try {
      final r = await ref.read(loyaltyRepositoryProvider).redeem(g);
      ref.invalidate(giftsProvider);
      ref.invalidate(redemptionsProvider);
      ref.read(dataVersionProvider.notifier).state++;
      if (mounted) {
        showAppSnack(context,
            'Đã gửi yêu cầu ${r.code}. ${r.points} điểm đang được giữ.');
      }
    } on ApiException catch (e) {
      if (mounted) {
        showAppSnack(context, e.message, error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _busyGift = '');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gifts = ref.watch(giftsProvider);
    final accountState = ref.watch(loyaltyAccountProvider);
    final account = accountState.isLoading || accountState.hasError
        ? null
        : accountState.valueOrNull;
    final redemptionState = ref.watch(redemptionsProvider);
    final redemptions = redemptionState.valueOrNull ?? const <GiftRedemption>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Đổi quà')),
      body: AsyncBody<List<Gift>>(
        value: gifts,
        onRetry: () => ref.invalidate(giftsProvider),
        builder: (list) => ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            if (accountState.isLoading) const LinearProgressIndicator(),
            if (accountState.hasError) ...[
              InfoBanner(text: ApiException.describe(accountState.error!)),
              TextButton(
                  onPressed: () => ref.invalidate(loyaltyAccountProvider),
                  child: const Text('Tải lại thẻ tích điểm')),
            ],
            if (account?.hasNegativeBalance == true)
              const InfoBanner(
                  text: 'Số dư điểm đang âm sau điều chỉnh. '
                      'Chưa thể gửi yêu cầu đổi quà mới; bạn vẫn xem được yêu cầu trước đó.'),
            if (account != null)
              InfoBanner(
                icon: Icons.stars_outlined,
                text: 'Bạn có ${account.balance} điểm khả dụng'
                    '${account.held > 0 ? ' (đang giữ ${account.held} điểm)' : ''}.',
              ),
            for (final g in list) _giftTile(g, account),
            if (redemptionState.isLoading) const LinearProgressIndicator(),
            if (redemptionState.hasError) ...[
              InfoBanner(text: ApiException.describe(redemptionState.error!)),
              TextButton(
                  onPressed: () => ref.invalidate(redemptionsProvider),
                  child: const Text('Tải lại yêu cầu đổi quà')),
            ],
            if (widget.redemptionId != null &&
                !redemptionState.isLoading &&
                !redemptionState.hasError &&
                redemptionState.hasValue &&
                !redemptions.any((r) => r.code == widget.redemptionId))
              const InfoBanner(
                  text:
                      'Không tìm thấy yêu cầu đổi quà nguồn trong tài khoản hiện tại.'),
            if (redemptions.isNotEmpty) ...<Widget>[
              const SectionTitle('Yêu cầu đổi quà của bạn'),
              for (final r in redemptions)
                AppCard(
                  color: r.code == widget.redemptionId
                      ? AppColors.primarySoft
                      : null,
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(r.giftName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            Text(
                              '${r.code} · ${AppDates.timeDay(r.requestedAt)} · ${r.points} điểm',
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      StatusChip(label: r.status.label, tone: r.status.tone),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _giftTile(Gift g, LoyaltyAccount? account) {
    final enough = account != null &&
        !account.hasNegativeBalance &&
        account.balance >= g.points;
    final available = g.stock > 0;
    return AppCard(
      child: Row(
        children: <Widget>[
          const CircleAvatar(
            backgroundColor: AppColors.primarySoft,
            child: Icon(Icons.card_giftcard, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(g.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('${g.code} · còn ${g.stock}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
                Text('${g.points} điểm',
                    style: const TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          FilledButton(
            onPressed: enough && available && _busyGift.isEmpty
                ? () => _redeem(g)
                : null,
            child: Text(_busyGift == g.code
                ? '...'
                : (!available ? 'Hết quà' : (enough ? 'Đổi' : 'Thiếu điểm'))),
          ),
        ],
      ),
    );
  }
}
