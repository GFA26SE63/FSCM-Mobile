import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/sync_snapshot.dart';

final syncApiProvider =
    Provider<SyncApi>((ref) => SyncApi(ref.watch(apiClientProvider)));

class SyncApi {
  SyncApi(this._client);

  final ApiClient _client;

  /// `GET /sync/snapshot?since=` - retailers in area, products, prices,
  /// promotions and the available stock summary.
  Future<SyncSnapshot> snapshot({DateTime? since}) async {
    final data = await _client.get(
      Endpoints.syncSnapshot,
      query: <String, dynamic>{
        'since': since == null ? null : AppDates.iso(since)
      },
    );
    return SyncSnapshot.fromJson(asMap(data));
  }
}
