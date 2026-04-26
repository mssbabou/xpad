/// Geolocation result from IP-based lookup.
class LocationData {
  final double latitude;
  final double longitude;
  final String city;
  final String country;
  final DateTime fetchedAt;

  const LocationData({
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.country,
    required this.fetchedAt,
  });

  @override
  String toString() => 'LocationData($city, $country — $latitude, $longitude)';
}
