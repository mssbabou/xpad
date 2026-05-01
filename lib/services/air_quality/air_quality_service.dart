import 'dart:async';

import '../../core/result.dart';
import 'air_quality_api.dart';
import 'air_quality_models.dart';

export '../../core/result.dart';
export 'air_quality_models.dart';

class AirQualityService {
  final AirQualityApi _api;
  double _latitude;
  double _longitude;

  AirQualityData? _cache;
  static const _cacheTtl = Duration(minutes: 30);

  AirQualityService({
    required double latitude,
    required double longitude,
    AirQualityApi? api,
  })  : _latitude = latitude,
        _longitude = longitude,
        _api = api ?? AirQualityApi();

  Future<Result<AirQualityData>> getCurrentAirQuality({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cache != null) {
      final age = DateTime.now().difference(_cache!.fetchedAt);
      if (age < _cacheTtl) {
        return Success(_cache!);
      }
    }

    final result = await _api.fetchCurrentAirQuality(
      latitude: _latitude,
      longitude: _longitude,
    );

    if (result case Success(:final data)) {
      _cache = data;
    }

    return result;
  }

  Stream<Result<AirQualityData>> airQualityStream({
    Duration interval = const Duration(minutes: 30),
  }) async* {
    yield await getCurrentAirQuality();
    yield* Stream.periodic(interval)
        .asyncMap((_) => getCurrentAirQuality());
  }

  /// Update coordinates and clear the cache so the next fetch uses the new location.
  void updateLocation(double latitude, double longitude) {
    _latitude = latitude;
    _longitude = longitude;
    _cache = null;
  }

  void clearCache() => _cache = null;

  void dispose() {
    _api.dispose();
  }
}
