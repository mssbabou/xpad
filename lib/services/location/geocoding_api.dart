import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/result.dart';
import 'location_models.dart';

class GeocodingApi {
  final http.Client _client;

  static const _baseUrl = 'https://geocoding-api.open-meteo.com/v1/search';
  static const _timeout = Duration(seconds: 10);

  GeocodingApi({http.Client? client}) : _client = client ?? http.Client();

  /// Search for a city by name, optionally filtering by country name or code.
  /// Returns the best matching [LocationData] or a typed [Failure].
  Future<Result<LocationData>> search(String city, {String? country}) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'name': city,
      'count': '10',
      'language': 'en',
      'format': 'json',
    });

    try {
      final response = await _client.get(uri).timeout(_timeout);

      if (response.statusCode != 200) {
        return Failure(AppError(
          kind: ErrorKind.server,
          message: 'Geocoding service unavailable',
          debugDetail: 'HTTP ${response.statusCode}',
        ));
      }

      return _parseResponse(response.body, country);
    } on http.ClientException catch (e) {
      return Failure(AppError(
        kind: ErrorKind.network,
        message: 'Could not reach geocoding service',
        debugDetail: e.message,
        originalError: e,
      ));
    } on TimeoutException catch (e) {
      return Failure(AppError(
        kind: ErrorKind.network,
        message: 'Geocoding request timed out',
        originalError: e,
      ));
    } catch (e) {
      return Failure(AppError(
        kind: ErrorKind.unknown,
        message: 'Something went wrong during geocoding',
        debugDetail: e.toString(),
        originalError: e,
      ));
    }
  }

  Result<LocationData> _parseResponse(String body, String? country) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final results = json['results'] as List?;

      if (results == null || results.isEmpty) {
        return Failure(AppError(
          kind: ErrorKind.parsing,
          message: 'City not found',
        ));
      }

      final items = results.cast<Map<String, dynamic>>();

      Map<String, dynamic>? match;
      if (country != null && country.trim().isNotEmpty) {
        final q = country.trim().toLowerCase();
        match = items.where((r) {
          final name = (r['country'] as String? ?? '').toLowerCase();
          final code = (r['country_code'] as String? ?? '').toLowerCase();
          return name == q || code == q;
        }).firstOrNull;
      }
      match ??= items.first;

      return Success(LocationData(
        latitude: (match['latitude'] as num).toDouble(),
        longitude: (match['longitude'] as num).toDouble(),
        city: match['name'] as String,
        country: match['country'] as String,
        fetchedAt: DateTime.now(),
      ));
    } catch (e) {
      return Failure(AppError(
        kind: ErrorKind.parsing,
        message: 'Could not read geocoding data',
        debugDetail: 'Parse error: $e',
        originalError: e,
      ));
    }
  }

  void dispose() => _client.close();
}
