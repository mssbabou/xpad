import 'package:shared_preferences/shared_preferences.dart';
import 'package:xpad/core/result.dart';
import 'package:xpad/services/octoprint/octoprint_api.dart';
import 'package:xpad/services/octoprint/octoprint_models.dart';

export 'package:xpad/services/octoprint/octoprint_models.dart';

class OctoPrintService {
  final OctoPrintApi _api;

  String _baseUrl = '';
  String _apiKey = '';

  static const _keyUrl = 'octoprint_url';
  static const _keyApiKey = 'octoprint_api_key';

  OctoPrintService({OctoPrintApi? api}) : _api = api ?? OctoPrintApi();

  bool get isConfigured => _baseUrl.isNotEmpty && _apiKey.isNotEmpty;
  String get baseUrl => _baseUrl;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_keyUrl) ?? '';
    _apiKey = prefs.getString(_keyApiKey) ?? '';
  }

  Future<void> saveConfig(String url, String apiKey) async {
    _baseUrl = url.trimRight().replaceAll(RegExp(r'/+$'), '');
    _apiKey = apiKey.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUrl, _baseUrl);
    await prefs.setString(_keyApiKey, _apiKey);
  }

  Stream<Result<OctoPrintStatus>> statusStream({
    Duration interval = const Duration(seconds: 3),
  }) async* {
    if (!isConfigured) return;
    yield await _api.getStatus(_baseUrl, _apiKey);
    yield* Stream.periodic(interval).asyncMap((_) => _api.getStatus(_baseUrl, _apiKey));
  }

  Future<Result<List<OctoPrintFile>>> getFiles() {
    if (!isConfigured) {
      return Future.value(Failure(AppError(
        kind: ErrorKind.unknown,
        message: 'OctoPrint not configured',
      )));
    }
    return _api.getFiles(_baseUrl, _apiKey);
  }

  Future<Result<void>> printFile(String path) {
    if (!isConfigured) return _notConfigured();
    return _api.printFile(_baseUrl, _apiKey, path);
  }

  Future<Result<void>> pause() {
    if (!isConfigured) return _notConfigured();
    return _api.pause(_baseUrl, _apiKey);
  }

  Future<Result<void>> resume() {
    if (!isConfigured) return _notConfigured();
    return _api.resume(_baseUrl, _apiKey);
  }

  Future<Result<void>> cancel() {
    if (!isConfigured) return _notConfigured();
    return _api.cancel(_baseUrl, _apiKey);
  }

  Future<Result<void>> preheat(int hotend, int bed) async {
    if (!isConfigured) return _notConfigured();
    await _api.setToolTemp(_baseUrl, _apiKey, hotend);
    return _api.setBedTemp(_baseUrl, _apiKey, bed);
  }

  Future<Result<void>> cooldown() => preheat(0, 0);

  Future<Result<String>> testConnection(String url, String apiKey) {
    final cleanUrl = url.trimRight().replaceAll(RegExp(r'/+$'), '');
    return _api.getVersion(cleanUrl, apiKey.trim());
  }

  Future<Result<void>> _notConfigured() => Future.value(Failure(AppError(
        kind: ErrorKind.unknown,
        message: 'OctoPrint not configured',
      )));

  void dispose() => _api.dispose();
}
