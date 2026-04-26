import 'package:shared_preferences/shared_preferences.dart';

import '../../core/result.dart';
import 'location_api.dart';
import 'location_models.dart';

export '../../core/result.dart';
export 'location_models.dart';

/// IP-based geolocation service. Persists to disk after the first
/// successful fetch — subsequent app starts skip the network call entirely.
class LocationService {
  final LocationApi _api;
  LocationData? _cache;

  static const _keyLat = 'location_latitude';
  static const _keyLon = 'location_longitude';
  static const _keyCity = 'location_city';
  static const _keyCountry = 'location_country';

  LocationService({LocationApi? api}) : _api = api ?? LocationApi();

  /// Get device location. Checks disk cache first, then network.
  /// Pass [forceRefresh] to skip all caches and re-fetch from IP.
  Future<Result<LocationData>> getLocation({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cache != null) {
      return Success(_cache!);
    }

    if (!forceRefresh) {
      final stored = await _loadFromDisk();
      if (stored != null) {
        _cache = stored;
        return Success(stored);
      }
    }

    final result = await _api.fetchLocation();

    if (result case Success(:final data)) {
      _cache = data;
      await _saveToDisk(data);
    }

    return result;
  }

  Future<LocationData?> _loadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_keyLat);
    final lon = prefs.getDouble(_keyLon);
    final city = prefs.getString(_keyCity);
    final country = prefs.getString(_keyCountry);

    if (lat == null || lon == null || city == null || country == null) {
      return null;
    }

    return LocationData(
      latitude: lat,
      longitude: lon,
      city: city,
      country: country,
      fetchedAt: DateTime.now(),
    );
  }

  Future<void> _saveToDisk(LocationData data) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setDouble(_keyLat, data.latitude),
      prefs.setDouble(_keyLon, data.longitude),
      prefs.setString(_keyCity, data.city),
      prefs.setString(_keyCountry, data.country),
    ]);
  }

  void dispose() {
    _api.dispose();
  }
}
