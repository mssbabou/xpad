import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/result.dart';
import 'weather_models.dart';

/// Low-level Open-Meteo HTTP client. Handles the network call and JSON
/// parsing. Separated from [WeatherService] so that:
///   1. HTTP details don't leak into business logic.
///   2. Tests can inject a mock [http.Client].
///   3. If Open-Meteo changes their JSON shape, only this file changes.
class WeatherApi {
  final http.Client _client;

  static const _baseUrl = 'https://api.open-meteo.com/v1/forecast';
  static const _currentParams =
      'temperature_2m,apparent_temperature,relative_humidity_2m,weather_code';
  static const _dailyParams  = 'temperature_2m_max,temperature_2m_min,sunrise,sunset';
  static const _hourlyParams = 'temperature_2m,weather_code';
  static const _timeout = Duration(seconds: 10);

  WeatherApi({http.Client? client}) : _client = client ?? http.Client();

  /// Fetch current weather for the given coordinates.
  /// Never throws — every failure path returns a typed [Failure].
  Future<Result<WeatherData>> fetchCurrentWeather({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'current': _currentParams,
      'daily': _dailyParams,
      'hourly': _hourlyParams,
      'forecast_days': '2',
      'timezone': 'auto',
    });

    try {
      final response = await _client.get(uri).timeout(_timeout);

      if (response.statusCode != 200) {
        return Failure(AppError(
          kind: ErrorKind.server,
          message: 'Weather service unavailable',
          debugDetail:
              'HTTP ${response.statusCode}: ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
        ));
      }

      return _parseResponse(response.body);
    } on http.ClientException catch (e) {
      return Failure(AppError(
        kind: ErrorKind.network,
        message: 'Could not reach weather service',
        debugDetail: e.message,
        originalError: e,
      ));
    } on TimeoutException catch (e) {
      return Failure(AppError(
        kind: ErrorKind.network,
        message: 'Weather request timed out',
        originalError: e,
      ));
    } on FormatException catch (e) {
      return Failure(AppError(
        kind: ErrorKind.parsing,
        message: 'Unexpected weather data format',
        debugDetail: e.message,
        originalError: e,
      ));
    } catch (e) {
      return Failure(AppError(
        kind: ErrorKind.unknown,
        message: 'Something went wrong fetching weather',
        debugDetail: e.toString(),
        originalError: e,
      ));
    }
  }

  Result<WeatherData> _parseResponse(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final current = json['current'] as Map<String, dynamic>;
      final daily = json['daily'] as Map<String, dynamic>;

      final hourly      = json['hourly'] as Map<String, dynamic>;
      final hourlyTimes = (hourly['time'] as List).cast<String>();
      final hourlyTemps = (hourly['temperature_2m'] as List).cast<num>();
      final hourlyCodes = (hourly['weather_code'] as List).cast<num>();

      final now = DateTime.now();
      final hourlyForecast = <HourlyWeather>[];
      for (var i = 0; i < hourlyTimes.length && hourlyForecast.length < 5; i++) {
        final t = DateTime.parse(hourlyTimes[i]);
        if (!t.isBefore(DateTime(now.year, now.month, now.day, now.hour))) {
          hourlyForecast.add(HourlyWeather(
            time: t,
            temperature: hourlyTemps[i].toDouble(),
            condition: WeatherCondition.fromWmoCode(hourlyCodes[i].toInt()),
          ));
        }
      }

      return Success(WeatherData(
        currentTemperature:  (current['temperature_2m'] as num).toDouble(),
        apparentTemperature: (current['apparent_temperature'] as num).toDouble(),
        relativeHumidity:    (current['relative_humidity_2m'] as num).toInt(),
        condition: WeatherCondition.fromWmoCode(
            (current['weather_code'] as num).toInt()),
        dailyMinTemperature:
            ((daily['temperature_2m_min'] as List).first as num).toDouble(),
        dailyMaxTemperature:
            ((daily['temperature_2m_max'] as List).first as num).toDouble(),
        hourlyForecast: hourlyForecast,
        sunrise: DateTime.parse((daily['sunrise'] as List).first as String),
        sunset:  DateTime.parse((daily['sunset']  as List).first as String),
        fetchedAt: DateTime.now(),
      ));
    } catch (e) {
      return Failure(AppError(
        kind: ErrorKind.parsing,
        message: 'Could not read weather data',
        debugDetail: 'Parse error: $e',
        originalError: e,
      ));
    }
  }

  void dispose() => _client.close();
}
