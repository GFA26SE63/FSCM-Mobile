import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/sync_snapshot.dart';

final syncApiProvider = Provider<SyncApi>(
  (ref) => SyncApi(ref.watch(apiClientProvider)),
);

class SyncApi {
  SyncApi(this._client);

  final ApiClient _client;

  Future<SyncSnapshot> snapshot({DateTime? since}) async {
    // BE hiện trả Full snapshot.
    // Không gửi since hoặc If-None-Match ở bước này.
    final data = await _client.get(Endpoints.syncSnapshot);

    try {
      return SyncSnapshot.fromJson(asMap(data));
    } on FormatException catch (error) {
      throw ApiException(
        kind: ApiErrorKind.server,
        message: 'Dữ liệu catalog từ máy chủ không hợp lệ.',
        details: error.message,
      );
    }
  }
}
