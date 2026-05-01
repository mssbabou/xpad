import 'package:shared_preferences/shared_preferences.dart';

import '../../core/result.dart';
import 'location_api.dart';
import 'location_models.dart';

export '../../core/result.dart';
export 'location_models.dart';

/// IP-based geolocation service with optional manual override.
///
/// Priority order for [getLocation]:
///   1. Manual override (if set) — always reads from disk, never re-fetches
///   2. In-memory cache
///   3. Disk cache (from previous IP lookup)
///   4. Network (ip-api.com)
class LocationService {
  final LocationApi _api;
  LocationData? _cache;

  static const _keyLat = 'location_latitude';
  static const _keyLon = 'location_longitude';
  static const _keyCity = 'location_city';
  static const _keyCountry = 'location_country';
  static const _keyManual = 'location_manual_override';

  LocationService({LocationApi? api}) : _api = api ?? LocationApi();

  /// Returns true if the user has set a manual location override.
  Future<bool> isManualOverride() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyManual) ?? false;
  }

  /// Get device location.
  ///
  /// If a manual override is active, always returns the stored manual location.
  /// Otherwise checks memory cache → disk cache → network.
  /// Pass [forceRefresh] to re-fetch from IP (ignored when manual override is set).
  Future<Result<LocationData>> getLocation({
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_keyManual) ?? false) {
      final stored = await _loadFromDisk();
      if (stored != null) {
        _cache = stored;
        return Success(stored);
      }
    }

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

  /// Persist a manually chosen location and activate the override flag.
  /// After calling this, [getLocation] will always return this location
  /// without hitting the network.
  Future<void> setManualLocation(LocationData data) async {
    _cache = data;
    await _saveToDisk(data);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyManual, true);
  }

  /// Remove the manual override and clear the disk cache so that the next
  /// call to [getLocation] falls through to the IP-based lookup.
  Future<void> clearManualLocation() async {
    _cache = null;
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_keyManual),
      prefs.remove(_keyLat),
      prefs.remove(_keyLon),
      prefs.remove(_keyCity),
      prefs.remove(_keyCountry),
    ]);
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
