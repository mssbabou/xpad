import 'package:shared_preferences/shared_preferences.dart';
import 'package:xpad/core/result.dart';
import 'package:xpad/services/hue/hue_api.dart';
import 'package:xpad/services/hue/hue_models.dart';

export 'package:xpad/core/result.dart';
export 'package:xpad/services/hue/hue_models.dart';

class HueService {
  final HueApi _api;

  String _bridgeIp = '';
  String _username = '';

  static const _keyIp = 'hue_bridge_ip';
  static const _keyUsername = 'hue_username';

  HueService({HueApi? api}) : _api = api ?? HueApi();

  bool get isConfigured => _bridgeIp.isNotEmpty && _username.isNotEmpty;
  String get bridgeIp => _bridgeIp;
  String get username => _username;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _bridgeIp = prefs.getString(_keyIp) ?? '';
    _username = prefs.getString(_keyUsername) ?? '';
  }

  Future<void> saveConfig(String ip, String username) async {
    _bridgeIp = ip.trim();
    _username = username.trim();
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_keyIp, _bridgeIp),
      prefs.setString(_keyUsername, _username),
    ]);
  }

  Future<Result<List<HueLight>>> getLights() {
    if (!isConfigured) return _notConfigured();
    return _api.getLights(_bridgeIp, _username);
  }

  Future<Result<void>> toggleLight(String id, bool on) {
    if (!isConfigured) return _notConfigured();
    return _api.setLightOn(_bridgeIp, _username, id, on);
  }

  Future<Result<List<String>>> discoverBridges() => _api.discoverBridges();

  Future<Result<String>> linkBridge(String ip) async {
    final trimmedIp = ip.trim();
    final result = await _api.registerApp(trimmedIp);
    if (result case Success(:final data)) {
      await saveConfig(trimmedIp, data);
    }
    return result;
  }

  Future<Result<T>> _notConfigured<T>() => Future.value(Failure(AppError(
        kind: ErrorKind.unknown,
        message: 'Hue not configured',
      )));

  void dispose() => _api.dispose();
}
