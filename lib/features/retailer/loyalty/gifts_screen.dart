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
  const GiftsScreen({super.key});

  @override
  ConsumerState<GiftsScreen> createState() => _GiftsScreenState();
}

class _GiftsScreenState extends ConsumerState<GiftsScreen> {
  String _busyGift = '';

  Future<void> _redeem(Gift g) async {
    final quantity = await _quantityDialog(g);
    if (quantity == null || !mounted) return;
    final ok = await confirmDialog(
      context,
      title: 'Đổi quà',
      message:
          'Đổi $quantity x "${g.name}" với ${g.points * quantity} điểm? Điểm sẽ được giữ cho đến khi yêu cầu được xử lý.',
      confirmLabel: 'Đổi quà',
    );
    if (!ok || !mounted) return;
    setState(() => _busyGift = g.code);
    try {
      final r = await ref.read(loyaltyRepositoryProvider)
          .redeem(g.id.isEmpty ? g.code : g.id, quantity: quantity);
      ref.invalidate(giftsProvider);
      ref.invalidate(redemptionsProvider);
      ref.read(dataVersionProvider.notifier).state++;
      if (mounted) {
        showAppSnack(context,
            'Đã gửi yêu cầu ${r.code}. ${r.points} điểm đang được giữ.');
      }
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busyGift = '');
    }
  }

  Future<int?> _quantityDialog(Gift g) async {
    final controller = TextEditingController(text: '1');
    final availablePoints = ref.read(loyaltyAccountProvider).valueOrNull?.balance ?? 0;
    final maxByPoints = g.points > 0 ? availablePoints ~/ g.points : 0;
    final max = [g.stock, maxByPoints].reduce((a, b) => a < b ? a : b);
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Số lượng ${g.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Số lượng (tối đa $max)',
            helperText: 'Tổng điểm: số lượng × ${g.points}',
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          FilledButton(
            onPressed: max <= 0
                ? null
                : () {
                    final value = int.tryParse(controller.text) ?? 0;
                    if (value < 1 || value > max) return;
                    Navigator.pop(context, value);
                  },
            child: const Text('Tiếp tục'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gifts = ref.watch(giftsProvider);
    final account = ref.watch(loyaltyAccountProvider).valueOrNull;
    final redemptions =
        ref.watch(redemptionsProvider).valueOrNull ?? const <GiftRedemption>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Đổi quà')),
      body: AsyncBody<List<Gift>>(
        value: gifts,
        onRetry: () => ref.invalidate(giftsProvider),
        builder: (list) => ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            if (account != null)
              InfoBanner(
                icon: Icons.stars_outlined,
                text: account.balance < 0
                    ? 'Điểm khả dụng đang âm (${account.balance}). Đổi quà mới đang bị khóa.'
                    : 'Bạn có ${account.balance} điểm khả dụng'
                    '${account.held > 0 ? ' (đang giữ ${account.held} điểm)' : ''}.',
              ),
            for (final g in list) _giftTile(g, account?.balance ?? 0),
            if (redemptions.isNotEmpty) ...<Widget>[
              const SectionTitle('Yêu cầu đổi quà của bạn'),
              for (final r in redemptions)
                AppCard(
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

  Widget _giftTile(Gift g, int balance) {
    final enough = balance >= g.points && balance >= 0;
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
