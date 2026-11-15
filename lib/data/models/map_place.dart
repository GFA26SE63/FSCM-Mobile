class MapSuggestion {
  const MapSuggestion({required this.referenceId, required this.display});

  final String referenceId;
  final String display;
}

class MapPlace {
  const MapPlace({
    required this.latitude,
    required this.longitude,
    required this.address,
    this.providerPlaceId,
  });

  final double latitude;
  final double longitude;
  final String address;
  final String? providerPlaceId;

  static bool validCoordinates(double? latitude, double? longitude) =>
      latitude != null &&
      longitude != null &&
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}
