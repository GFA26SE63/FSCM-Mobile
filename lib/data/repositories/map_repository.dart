import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fscm_mobile/data/models/map_place.dart';
import 'package:fscm_mobile/data/remote/vietmap_api.dart';

final mapRepositoryProvider = Provider<MapRepository>(
    (ref) => MapRepository(ref.watch(vietMapApiProvider)));

class MapRepository {
  MapRepository(this._api);
  final VietMapApi _api;

  Future<List<MapSuggestion>> search(String text) => _api.search(text);
  Future<MapPlace> place(MapSuggestion suggestion) => _api.place(suggestion);
}
