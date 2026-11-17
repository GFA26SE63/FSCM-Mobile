import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/data/models/loyalty.dart';
import 'package:fscm_mobile/data/models/redemption_attempt.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';
import 'package:fscm_mobile/data/repositories/loyalty_repository.dart';
import 'package:fscm_mobile/features/retailer/loyalty/widgets/gift_catalog_tile.dart';
import 'package:fscm_mobile/features/retailer/loyalty/widgets/gift_redemption_tile.dart';
import 'package:fscm_mobile/features/retailer/loyalty/widgets/gift_redeem_sheet.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';

/// Catalogue, independent own-request history and explicit retry of uncertain sends.
class GiftsScreen extends ConsumerStatefulWidget {
  const GiftsScreen({super.key, this.redemptionId});
  final String? redemptionId;
  @override
  ConsumerState<GiftsScreen> createState() => _GiftsScreenState();
}

class _GiftsScreenState extends ConsumerState<GiftsScreen> {
  bool _busy = false;
  bool _refreshing = false;
  String? _error;

  Future<void> _reload() async {
    if (_refreshing) {
      return;
    }
    setState(() => _refreshing = true);
    ref.invalidate(loyaltyAccountProvider);
    ref.invalidate(giftsProvider);
    ref.invalidate(redemptionsProvider);
    ref.invalidate(pendingRedemptionProvider);
    try {
      await Future.wait<Object?>([
        ref.read(loyaltyAccountProvider.future), ref.read(giftsProvider.future),
        ref.read(redemptionsProvider.future), ref.read(pendingRedemptionProvider.future),
      ]);
    } catch (_) {
      // Each independent section displays its actual provider error.
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || _refreshing) {
      return;
    }
    setState(() { _busy = true; _error = null; });
    final owner = ref.read(currentUserProvider)?.id;
    try {
      await action();
    } catch (error) {
      if (mounted && ref.read(currentUserProvider)?.id == owner) {
        setState(() => _error = ApiException.describe(error));
      }
    } finally {
      if (mounted) {
        ref.invalidate(pendingRedemptionProvider);
        setState(() => _busy = false);
      }
    }
  }

  void _checkOwner(String owner) {
    if (!mounted || ref.read(currentUserProvider)?.id != owner) {
      throw const ApiException(kind: ApiErrorKind.unauthorized,
        message: 'Phiên đăng nhập đã thay đổi.');
    }
  }

  Future<void> _redeem(Gift gift) => _run(() async {
    final owner = ref.read(currentUserProvider)?.id;
    if (owner == null) {
      return;
    }
    final card = ref.read(loyaltyAccountProvider).valueOrNull;
    if (card == null || card.balance < gift.points || card.hasNegativeBalance || card.program?.isActive != true) {
      return;
    }
    final quantity = await showModalBottomSheet<int>(context: context, isScrollControlled: true,
      builder: (_) => GiftRedeemSheet(gift: gift, balance: card.balance));
    if (quantity == null) {
      return;
    }
    _checkOwner(owner);
    final latest = ref.read(loyaltyAccountProvider);
    if (latest.isLoading || latest.hasError || latest.valueOrNull == null ||
        latest.requireValue.retailerId != card.retailerId ||
        latest.requireValue.programId != gift.programId ||
        latest.requireValue.balance < gift.points * quantity || latest.requireValue.program?.isActive != true) {
      throw const ApiException(kind: ApiErrorKind.conflict,
        message: 'Thông tin điểm hoặc chương trình đã thay đổi. Hãy tải lại trước khi đổi quà.');
    }
    final attempt = await ref.read(redemptionAttemptStoreProvider).create(
      ownerId: owner, retailerId: card.retailerId, gift: gift, quantity: quantity);
    _checkOwner(owner);
    ref.invalidate(pendingRedemptionProvider);
    await _submit(attempt);
  });

  Future<void> _submit(RedemptionAttempt attempt) async {
    _checkOwner(attempt.ownerId);
    final repository = ref.read(loyaltyRepositoryProvider);
    final store = ref.read(redemptionAttemptStoreProvider);
    // Reconcile before POST, including after an app restart. No automatic send.
    final history = await repository.redemptions();
    _checkOwner(attempt.ownerId);
    final existing = history.where((r) => r.clientRequestId == attempt.operationKey);
    GiftRedemption result;
    if (existing.isNotEmpty) {
      result = existing.first;
    } else {
      final card = await ref.read(loyaltyAccountProvider.future);
      _checkOwner(attempt.ownerId);
      if (card.retailerId != attempt.retailerId) {
        throw const ApiException(kind: ApiErrorKind.forbidden,
          message: 'Yêu cầu đổi quà thuộc điểm bán khác.');
      }
      await store.markSent(attempt);
      _checkOwner(attempt.ownerId);
      try {
        result = await repository.redeem(attempt);
      } on ApiException catch (error) {
        // A first explicit business rejection has a known result. An earlier
        // uncertain send keeps its key even when a later retry is rejected.
        if (!attempt.mayHaveSucceeded &&
            [400, 404, 409, 422].contains(error.statusCode)) {
          await store.complete(attempt.ownerId, attempt.operationKey);
        }
        rethrow;
      }
    }
    await store.complete(attempt.ownerId, attempt.operationKey);
    _checkOwner(attempt.ownerId);
    ref.invalidate(giftsProvider);
    ref.invalidate(redemptionsProvider);
    ref.read(dataVersionProvider.notifier).state++;
    if (!mounted) {
      return;
    }
    showAppSnack(context, 'Đã xác nhận yêu cầu ${result.code}: ${result.status.label}.');
  }

  @override
  Widget build(BuildContext context) {
    final gifts = ref.watch(giftsProvider);
    final accountState = ref.watch(loyaltyAccountProvider);
    final account = accountState.isLoading || accountState.hasError ? null : accountState.valueOrNull;
    final requests = ref.watch(redemptionsProvider);
    final pending = ref.watch(pendingRedemptionProvider);
    final blocked = _busy || _refreshing || pending.isLoading || pending.hasError ||
        pending.valueOrNull != null || account?.program?.isActive != true;
    return Scaffold(
      appBar: AppBar(title: const Text('Đổi quà'), actions: [IconButton(
        tooltip: 'Tải lại quà, điểm và yêu cầu', onPressed: _busy || _refreshing ? null : () => unawaited(_reload()),
        icon: const Icon(Icons.refresh))]),
      body: RefreshIndicator(onRefresh: _reload, child: ListView(
        physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
        if (_error != null) InfoBanner(text: _error!),
        if (accountState.isLoading || pending.isLoading) const LinearProgressIndicator(),
        if (accountState.hasError) InfoBanner(text: ApiException.describe(accountState.error!)),
        if (account != null) InfoBanner(icon: Icons.stars_outlined,
          text: 'Bạn có ${account.balance} điểm khả dụng (đang giữ ${account.held} điểm).'),
        if (account?.program?.isActive == false) const InfoBanner(
          text: 'Chương trình đang tạm dừng. Chưa thể gửi yêu cầu đổi quà mới; bạn vẫn xem được các yêu cầu đã gửi.'),
        if (account?.hasNegativeBalance == true) const InfoBanner(
          text: 'Số dư điểm đang âm sau điều chỉnh. Chưa thể gửi yêu cầu đổi quà mới; bạn vẫn xem được yêu cầu trước đó.'),
        if (pending.hasError) ...[
          InfoBanner(text: ApiException.describe(pending.error!)),
          TextButton(onPressed: _busy ? null : () => ref.invalidate(pendingRedemptionProvider), child: const Text('Tải lại yêu cầu trên máy')),
        ],
        if (pending.valueOrNull case final RedemptionAttempt attempt) AppCard(child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Yêu cầu chưa xác nhận kết quả', style: TextStyle(fontWeight: FontWeight.w700)),
          Text('${attempt.giftName} · ${attempt.quantity} quà · ${attempt.totalPoints} điểm khi gửi'),
          const Text('Kiểm tra hoặc thử lại yêu cầu này trước khi đổi quà mới. Nội dung yêu cầu được giữ nguyên.'),
          FilledButton(onPressed: _busy || _refreshing ? null : () => unawaited(_run(() => _submit(attempt))),
            child: Text(_busy ? 'Đang xử lý…' : 'Kiểm tra và thử lại')),
        ])),
        const SectionTitle('Danh mục quà'),
        AsyncBody<List<Gift>>(value: gifts, onRetry: () => unawaited(_reload()), builder: (list) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (list.isEmpty) Text(account?.programId == null
              ? 'Chưa có chương trình áp dụng để đổi quà.' : 'Chưa có quà đang hoạt động trong chương trình này.'),
          for (final gift in list) GiftCatalogTile(gift: gift, account: account, busy: blocked,
            onRedeem: () => unawaited(_redeem(gift))),
        ])),
        const SectionTitle('Yêu cầu đổi quà của bạn'),
        AsyncBody<List<GiftRedemption>>(value: requests,
          onRetry: () => ref.invalidate(redemptionsProvider), builder: (list) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (widget.redemptionId != null && !list.any((r) => r.code == widget.redemptionId))
            const InfoBanner(text: 'Không tìm thấy yêu cầu đổi quà nguồn trong tài khoản hiện tại.'),
          if (list.isEmpty) const Text('Chưa có yêu cầu đổi quà.'),
          for (final request in list) GiftRedemptionTile(request: request, highlight: request.code == widget.redemptionId),
        ])),
      ])),
    );
  }
}
