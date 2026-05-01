import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/result.dart';
import 'air_quality_models.dart';

class AirQualityApi {
  final http.Client _client;

  static const _baseUrl = 'https://air-quality-api.open-meteo.com/v1/air-quality';
  static const _currentParams =
      'pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone,'
      'aerosol_optical_depth,dust,uv_index,uv_index_clear_sky,'
      'european_aqi,us_aqi,'
      'alder_pollen,birch_pollen,grass_pollen,mugwort_pollen,olive_pollen,ragweed_pollen,ammonia';
  static const _timeout = Duration(seconds: 10);

  AirQualityApi({http.Client? client}) : _client = client ?? http.Client();

  Future<Result<AirQualityData>> fetchCurrentAirQuality({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'current': _currentParams,
    });

    try {
      final response = await _client.get(uri).timeout(_timeout);

      if (response.statusCode != 200) {
        return Failure(AppError(
          kind: ErrorKind.server,
          message: 'Air quality service unavailable',
          debugDetail:
              'HTTP ${response.statusCode}: ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
        ));
      }

      return _parseResponse(response.body);
    } on http.ClientException catch (e) {
      return Failure(AppError(
        kind: ErrorKind.network,
        message: 'Could not reach air quality service',
        debugDetail: e.message,
        originalError: e,
      ));
    } on TimeoutException catch (e) {
      return Failure(AppError(
        kind: ErrorKind.network,
        message: 'Air quality request timed out',
        originalError: e,
      ));
    } on FormatException catch (e) {
      return Failure(AppError(
        kind: ErrorKind.parsing,
        message: 'Unexpected air quality data format',
        debugDetail: e.message,
        originalError: e,
      ));
    } catch (e) {
      return Failure(AppError(
        kind: ErrorKind.unknown,
        message: 'Something went wrong fetching air quality',
        debugDetail: e.toString(),
        originalError: e,
      ));
    }
  }

  Result<AirQualityData> _parseResponse(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final current = json['current'] as Map<String, dynamic>;

      double req(String key) => (current[key] as num).toDouble();
      double? opt(String key) => (current[key] as num?)?.toDouble();

      return Success(AirQualityData(
        europeanAqi:         (current['european_aqi'] as num).toInt(),
        usAqi:               (current['us_aqi'] as num).toInt(),
        pm10:                req('pm10'),
        pm2_5:               req('pm2_5'),
        uvIndex:             req('uv_index'),
        uvIndexClearSky:     req('uv_index_clear_sky'),
        carbonMonoxide:      req('carbon_monoxide'),
        nitrogenDioxide:     req('nitrogen_dioxide'),
        sulphurDioxide:      req('sulphur_dioxide'),
        ozone:               req('ozone'),
        dust:                req('dust'),
        aerosolOpticalDepth: req('aerosol_optical_depth'),
        alderPollen:         opt('alder_pollen'),
        birchPollen:         opt('birch_pollen'),
        grassPollen:         opt('grass_pollen'),
        mugwortPollen:       opt('mugwort_pollen'),
        olivePollen:         opt('olive_pollen'),
        ragweedPollen:       opt('ragweed_pollen'),
        ammonia:             opt('ammonia'),
        fetchedAt:           DateTime.now(),
      ));
    } catch (e) {
      return Failure(AppError(
        kind: ErrorKind.parsing,
        message: 'Could not read air quality data',
        debugDetail: 'Parse error: $e',
        originalError: e,
      ));
    }
  }

  void dispose() => _client.close();
}
