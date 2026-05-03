import 'dart:async';

import '../../core/result.dart';
import 'weather_api.dart';
import 'weather_models.dart';

export '../../core/result.dart';
export 'weather_models.dart';

/// Application-level weather service. This is the single import the UI needs.
///
/// Currently a thin wrapper around [WeatherApi] with in-memory caching.
/// As the app grows, this layer is where you add:
///   - Retry logic with exponential backoff
///   - Coordinate resolution (city name → lat/lon)
///   - Combining multiple API calls into richer models
class WeatherService {
  final WeatherApi _api;
  double _latitude;
  double _longitude;

  WeatherData? _cache;
  static const _cacheTtl = Duration(minutes: 10);

  WeatherService({
    required double latitude,
    required double longitude,
    WeatherApi? api,
  })  : _latitude = latitude,
        _longitude = longitude,
        _api = api ?? WeatherApi();

  /// Get current weather snapshot.
  ///
  /// Returns cached data if it's less than 10 minutes old.
  /// Pass [forceRefresh] to bypass the cache.
  Future<Result<WeatherData>> getCurrentWeather({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cache != null) {
      final age = DateTime.now().difference(_cache!.fetchedAt);
      if (age < _cacheTtl) {
        return Success(_cache!);
      }
    }

    final result = await _api.fetchCurrentWeather(
      latitude: _latitude,
      longitude: _longitude,
    );

    if (result case Success(:final data)) {
      _cache = data;
    }

    return result;
  }

  /// Periodic stream of weather results. Fetches immediately, then
  /// every [interval]. Cache still applies — if the interval is shorter
  /// than the cache TTL, intermediate ticks return cached data for free.
  Stream<Result<WeatherData>> weatherStream({
    Duration interval = const Duration(minutes: 15),
  }) async* {
    yield await getCurrentWeather();
    yield* Stream.periodic(interval)
        .asyncMap((_) => getCurrentWeather());
  }

  /// Update coordinates and clear the cache so the next fetch uses the new location.
  void updateLocation(double latitude, double longitude) {
    _latitude = latitude;
    _longitude = longitude;
    _cache = null;
  }

  /// Discard cached data. Useful after a location change.
  void clearCache() => _cache = null;

  void dispose() {
    _api.dispose();
  }
}
