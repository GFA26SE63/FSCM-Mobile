import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/network_monitor.dart';
import 'package:fscm_mobile/data/local/local_providers.dart';
import 'package:fscm_mobile/data/remote/order_configuration_api.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';

/// Keep the last verified step for this account, independently of snapshot stock.
final orderStepProvider = FutureProvider.autoDispose<int>((ref) async {
  final user = ref.watch(currentUserProvider);
  final online = ref.watch(networkMonitorProvider).online;
  ref.watch(dataVersionProvider);
  if (user == null) {
    throw const ApiException(
        kind: ApiErrorKind.unauthorized, message: 'Vui lòng đăng nhập lại.');
  }
  var disposed = false;
  ref.onDispose(() => disposed = true);
  final dao = ref.watch(syncStateDaoProvider);
  final api = ref.watch(orderConfigurationApiProvider);
  final key = 'order_step.v1.${user.id}';
  void requireSession() {
    if (disposed || ref.read(currentUserProvider)?.id != user.id) {
      throw const ApiException(
          kind: ApiErrorKind.unauthorized,
          message: 'Phiên đăng nhập đã thay đổi.');
    }
  }

  if (online) {
    try {
      final step = await api.orderStep();
      requireSession();
      await dao.set(key, '$step');
      requireSession();
      return step;
    } on ApiException catch (error) {
      if (!error.isNetwork) {
        rethrow;
      }
      // A network failure may use a previously verified value, never a guess.
    }
  }
  final cached = int.tryParse(await dao.get(key) ?? '');
  requireSession();
  if (cached != null && cached > 0) {
    return cached;
  }
  throw const ApiException(
      kind: ApiErrorKind.network,
      message:
          'Chưa có bước đặt hàng đã xác minh. Kết nối máy chủ để tải cấu hình.');
});
