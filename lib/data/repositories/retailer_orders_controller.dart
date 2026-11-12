import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/remote/orders_api.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';

class RetailerOrdersState {
  const RetailerOrdersState(
      {required this.orders,
      required this.totalCount,
      required this.page,
      required this.hasMore,
      this.loadingMore = false,
      this.moreError});
  final List<Order> orders;
  final int totalCount;
  final int page;
  final bool hasMore;
  final bool loadingMore;
  final String? moreError;

  RetailerOrdersState withProgress({bool loadingMore = false, String? error}) =>
      RetailerOrdersState(
        orders: orders,
        totalCount: totalCount,
        page: page,
        hasMore: hasMore,
        loadingMore: loadingMore,
        moreError: error,
      );
}

final retailerOrdersProvider = StateNotifierProvider.autoDispose
    .family<RetailerOrdersController, AsyncValue<RetailerOrdersState>, String>(
        (ref, search) {
  final user = ref.watch(currentUserProvider);
  ref.watch(dataVersionProvider);
  return RetailerOrdersController(
    ref.watch(ordersApiProvider),
    search: search,
    isCurrentUser: () =>
        user != null &&
        user.role == UserRole.retailer &&
        ref.read(currentUserProvider)?.id == user.id,
  );
});

class RetailerOrdersController
    extends StateNotifier<AsyncValue<RetailerOrdersState>> {
  RetailerOrdersController(this._api,
      {required String search, required bool Function() isCurrentUser})
      : _search = search,
        _isCurrentUser = isCurrentUser,
        super(const AsyncLoading()) {
    unawaited(refresh());
  }
  final OrdersApi _api;
  final String _search;
  final bool Function() _isCurrentUser;
  int _generation = 0;

  bool get _active => mounted && _isCurrentUser();

  Future<void> refresh() async {
    if (!mounted) {
      return;
    }
    final generation = ++_generation;
    if (!_active) {
      state = const AsyncError(
          ApiException(
              kind: ApiErrorKind.forbidden,
              message: 'Cần đăng nhập Retailer để xem đơn của cửa hàng.'),
          StackTrace.empty);
      return;
    }
    state = const AsyncLoading();
    try {
      final page = await _api.listPage(search: _search);
      if (!_active || generation != _generation) {
        return;
      }
      state = AsyncData(RetailerOrdersState(
          orders: page.items,
          totalCount: page.totalCount,
          page: page.page,
          hasMore: page.hasMore));
    } catch (error, stack) {
      if (_active && generation == _generation) {
        state = AsyncError(error, stack);
      }
    }
  }

  Future<void> loadMore() async {
    if (!_active) {
      return;
    }
    final current = state.valueOrNull;
    if (current == null ||
        current.loadingMore ||
        !current.hasMore ||
        state.isLoading) {
      return;
    }
    final generation = _generation;
    state = AsyncData(current.withProgress(loadingMore: true));
    try {
      final page = await _api.listPage(page: current.page + 1, search: _search);
      if (!_active || generation != _generation) {
        return;
      }
      final byId = {for (final order in current.orders) order.id: order};
      for (final order in page.items) {
        byId[order.id] = order;
      }
      state = AsyncData(RetailerOrdersState(
          orders: byId.values.toList(),
          totalCount: page.totalCount,
          page: page.page,
          hasMore: page.hasMore));
    } catch (error) {
      if (_active && generation == _generation) {
        state = AsyncData(
            current.withProgress(error: ApiException.describe(error)));
      }
    }
  }
}
