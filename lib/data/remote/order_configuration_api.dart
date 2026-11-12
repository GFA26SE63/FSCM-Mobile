import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/pricing/order_limits.dart';

final orderConfigurationApiProvider = Provider<OrderConfigurationApi>(
    (ref) => OrderConfigurationApi(ref.watch(apiClientProvider)));

class OrderConfigurationApi {
  OrderConfigurationApi(this._client);
  final ApiClient _client;

  Future<int> orderStep() async {
    final data = await _client.get('/configurations');
    if (data is! List || data.any((item) => item is! Map)) {
      throw const ApiException(
          kind: ApiErrorKind.server,
          message: 'Phản hồi cấu hình không hợp lệ.');
    }
    final rows = asMapList(data).where((row) =>
        row['key'] == 'order.order_step_cartons' && row['isActive'] == true);
    // A successful response with no active setting uses the backend fallback.
    if (rows.isEmpty) {
      return OrderLimits.step;
    }
    if (rows.length != 1) {
      throw const ApiException(
          kind: ApiErrorKind.server,
          message: 'Cấu hình bước đặt hàng bị trùng.');
    }
    final value = rows.single['value'];
    final step = value is int ? value : int.tryParse('$value');
    if (step == null || step <= 0) {
      throw const ApiException(
          kind: ApiErrorKind.conflict,
          message: 'Bước số lượng đặt hàng trên máy chủ không hợp lệ.');
    }
    return step;
  }
}
