import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/retailer.dart';
import 'package:fscm_mobile/data/models/sales_order_quote.dart';
import 'package:fscm_mobile/data/remote/quotes_api.dart';
import 'package:fscm_mobile/data/remote/sync_api.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';

/// Read fresh approved terms from the retailer-scoped snapshot, never from an SO
/// whose payment has not yet been selected (its creditTermDays can still be 0).
final retailerCreditProvider =
    FutureProvider.family<Retailer, String>((ref, retailerId) async {
  final user = ref.watch(currentUserProvider);
  var disposed = false;
  ref.onDispose(() => disposed = true);
  ref.watch(dataVersionProvider);
  if (user == null || user.role != UserRole.retailer || retailerId.isEmpty) {
    throw const ApiException(
        kind: ApiErrorKind.forbidden,
        message: 'Không xác định được cửa hàng để kiểm tra công nợ.');
  }
  final snapshot = await ref.watch(syncApiProvider).snapshot();
  if (disposed || ref.read(currentUserProvider)?.id != user.id) {
    throw const ApiException(
        kind: ApiErrorKind.unauthorized,
        message: 'Phiên đăng nhập đã thay đổi.');
  }
  final own = snapshot.retailers.where((retailer) =>
      retailer.id == retailerId &&
      (user.retailerCode == null ||
          user.retailerCode!.isEmpty ||
          retailer.code == user.retailerCode));
  if (own.length != 1) {
    throw const ApiException(
        kind: ApiErrorKind.forbidden,
        message:
            'Không tìm thấy cửa hàng của bạn trong dữ liệu được cấp quyền.');
  }
  return own.single;
});

/// The signed-in Retailer can read only their own approved credit profile.
final ownRetailerCreditProvider = FutureProvider<Retailer>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null ||
      user.role != UserRole.retailer ||
      user.retailerCode == null ||
      user.retailerCode!.isEmpty) {
    throw const ApiException(
        kind: ApiErrorKind.forbidden,
        message: 'Không xác định được cửa hàng của phiên đăng nhập.');
  }
  final snapshot = await ref.watch(syncApiProvider).snapshot();
  final own =
      snapshot.retailers.where((item) => item.code == user.retailerCode);
  if (own.length != 1) {
    throw const ApiException(
        kind: ApiErrorKind.forbidden,
        message: 'Không tìm thấy hồ sơ công nợ của cửa hàng được cấp quyền.');
  }
  return own.single;
});

bool retailerCreditAllowed(Retailer retailer) =>
    retailer.status == 'Active' &&
    const [7, 14, 30].contains(retailer.creditTerm);

final retailerOrderActionsProvider = Provider<RetailerOrderActions>((ref) {
  final user = ref.watch(currentUserProvider);
  return RetailerOrderActions(ref, user?.id ?? '', user?.role);
});

class RetailerOrderActions {
  RetailerOrderActions(this._ref, this._userId, this._role) {
    _ref.onDispose(() => _disposed = true);
  }
  final Ref _ref;
  final String _userId;
  final UserRole? _role;
  bool _disposed = false;

  void _requireSession(Order order, SalesOrderQuote quote) {
    if (_disposed ||
        _role != UserRole.retailer ||
        _userId.isEmpty ||
        _ref.read(currentUserProvider)?.id != _userId) {
      throw const ApiException(
          kind: ApiErrorKind.forbidden,
          message:
              'Cần đăng nhập đúng tài khoản Retailer để quyết định báo giá.');
    }
    if (order.id != quote.salesOrderId || order.status != OrderStatus.quoted) {
      throw const ApiException(
          kind: ApiErrorKind.conflict,
          message: 'Đơn không còn chờ quyết định báo giá. Hãy tải lại.');
    }
  }

  void _refresh() {
    if (!_disposed && _ref.read(currentUserProvider)?.id == _userId) {
      _ref.read(dataVersionProvider.notifier).state++;
    }
  }

  Future<SalesOrderQuote> accept(
      Order order, SalesOrderQuote quote, PaymentMethod method) async {
    _requireSession(order, quote);
    if (method == PaymentMethod.credit) {
      // Recheck approved terms when the actual decision is submitted.
      _ref.invalidate(retailerCreditProvider(order.retailerId));
      final retailer =
          await _ref.read(retailerCreditProvider(order.retailerId).future);
      _requireSession(order, quote);
      if (!retailerCreditAllowed(retailer)) {
        throw const ApiException(
            kind: ApiErrorKind.validation,
            message:
                'Cửa hàng chưa có kỳ hạn công nợ được duyệt (7, 14 hoặc 30 ngày).');
      }
    }
    final api = _ref.read(quotesApiProvider);
    try {
      return await api.accept(quote, method);
    } finally {
      _refresh();
    }
  }

  Future<SalesOrderQuote> reject(
      Order order, SalesOrderQuote quote, String reason) async {
    _requireSession(order, quote);
    final api = _ref.read(quotesApiProvider);
    try {
      return await api.reject(quote, reason);
    } finally {
      _refresh();
    }
  }
}
