import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/result.dart';
import 'location_models.dart';

class LocationApi {
  final http.Client _client;

  static const _url = 'http://ip-api.com/json/?fields=lat,lon,city,country';
  static const _timeout = Duration(seconds: 10);

  LocationApi({http.Client? client}) : _client = client ?? http.Client();

  Future<Result<LocationData>> fetchLocation() async {
    try {
      final response =
          await _client.get(Uri.parse(_url)).timeout(_timeout);

      if (response.statusCode != 200) {
        return Failure(AppError(
          kind: ErrorKind.server,
          message: 'Location service unavailable',
          debugDetail:
              'HTTP ${response.statusCode}: ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
        ));
      }

      return _parseResponse(response.body);
    } on http.ClientException catch (e) {
      return Failure(AppError(
        kind: ErrorKind.network,
        message: 'Could not reach location service',
        debugDetail: e.message,
        originalError: e,
      ));
    } on TimeoutException catch (e) {
      return Failure(AppError(
        kind: ErrorKind.network,
        message: 'Location request timed out',
        originalError: e,
      ));
    } on FormatException catch (e) {
      return Failure(AppError(
        kind: ErrorKind.parsing,
        message: 'Unexpected location data format',
        debugDetail: e.message,
        originalError: e,
      ));
    } catch (e) {
      return Failure(AppError(
        kind: ErrorKind.unknown,
        message: 'Something went wrong fetching location',
        debugDetail: e.toString(),
        originalError: e,
      ));
    }
  }

  Result<LocationData> _parseResponse(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;

      return Success(LocationData(
        latitude: (json['lat'] as num).toDouble(),
        longitude: (json['lon'] as num).toDouble(),
        city: json['city'] as String,
        country: json['country'] as String,
        fetchedAt: DateTime.now(),
      ));
    } catch (e) {
      return Failure(AppError(
        kind: ErrorKind.parsing,
        message: 'Could not read location data',
        debugDetail: 'Parse error: $e',
        originalError: e,
      ));
    }
  }

  void dispose() => _client.close();
}
