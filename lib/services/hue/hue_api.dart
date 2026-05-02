import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xpad/core/result.dart';
import 'package:xpad/services/hue/hue_models.dart';

class HueApi {
  final http.Client _client;

  HueApi({http.Client? client}) : _client = client ?? http.Client();

  Future<Result<List<HueLight>>> getLights(String ip, String username) async {
    try {
      final response = await _client
          .get(Uri.parse('http://$ip/api/$username/lights'))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        return Failure(AppError(
          kind: ErrorKind.server,
          message: 'Bridge returned ${response.statusCode}',
        ));
      }

      final Map<String, dynamic> body = jsonDecode(response.body);

      if (body.isNotEmpty && body.values.first is List) {
        final errors = body.values.first as List;
        if (errors.isNotEmpty && errors.first is Map && errors.first['error'] != null) {
          final desc = errors.first['error']['description'] as String? ?? 'Unknown error';
          return Failure(AppError(kind: ErrorKind.server, message: desc));
        }
      }

      final lights = body.entries.map((e) {
        final data = e.value as Map<String, dynamic>;
        return HueLight(
          id: e.key,
          name: data['name'] as String? ?? e.key,
          state: HueLightState.fromJson(data['state'] as Map<String, dynamic>? ?? {}),
        );
      }).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      return Success(lights);
    } on Exception catch (e) {
      return Failure(AppError(
        kind: ErrorKind.network,
        message: 'Could not reach bridge',
        debugDetail: e.toString(),
      ));
    }
  }

  Future<Result<void>> setLightOn(String ip, String username, String id, bool on) async {
    try {
      final response = await _client
          .put(
            Uri.parse('http://$ip/api/$username/lights/$id/state'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'on': on}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        return Failure(AppError(
          kind: ErrorKind.server,
          message: 'Bridge returned ${response.statusCode}',
        ));
      }

      return const Success(null);
    } on Exception catch (e) {
      return Failure(AppError(
        kind: ErrorKind.network,
        message: 'Could not reach bridge',
        debugDetail: e.toString(),
      ));
    }
  }

  Future<Result<String>> registerApp(String ip) async {
    try {
      final response = await _client
          .post(
            Uri.parse('http://$ip/api'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'devicetype': 'xpad#raspberry'}),
          )
          .timeout(const Duration(seconds: 10));

      final List<dynamic> body = jsonDecode(response.body);
      if (body.isEmpty) {
        return Failure(AppError(kind: ErrorKind.server, message: 'Empty response from bridge'));
      }

      final entry = body.first as Map<String, dynamic>;
      if (entry.containsKey('success')) {
        final username = entry['success']['username'] as String;
        return Success(username);
      }

      final error = entry['error'] as Map<String, dynamic>?;
      final type = error?['type'] as int?;
      if (type == 101) {
        return Failure(AppError(
          kind: ErrorKind.server,
          message: 'Press the button on your Hue Bridge first, then try again',
        ));
      }

      final desc = error?['description'] as String? ?? 'Unknown error';
      return Failure(AppError(kind: ErrorKind.server, message: desc));
    } on Exception catch (e) {
      return Failure(AppError(
        kind: ErrorKind.network,
        message: 'Could not reach bridge',
        debugDetail: e.toString(),
      ));
    }
  }

  Future<Result<List<String>>> discoverBridges() async {
    try {
      final response = await _client
          .get(Uri.parse('https://discovery.meethue.com/'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return Failure(AppError(kind: ErrorKind.server, message: 'Discovery failed'));
      }

      final List<dynamic> body = jsonDecode(response.body);
      final candidates = body
          .whereType<Map<String, dynamic>>()
          .map((e) => e['internalipaddress'] as String?)
          .whereType<String>()
          .toList();

      if (candidates.isEmpty) {
        return Failure(AppError(kind: ErrorKind.unknown, message: 'No bridges found on this network'));
      }

      return Success(candidates);
    } on Exception catch (e) {
      return Failure(AppError(
        kind: ErrorKind.network,
        message: 'Discovery failed: ${e.toString()}',
      ));
    }
  }


  void dispose() => _client.close();
}
