import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

class DisplaySpecs {
  final int? width;
  final int? height;
  final int? refreshRate;

  const DisplaySpecs({this.width, this.height, this.refreshRate});
}

/// Controls screen brightness via Linux sysfs backlight interface.
/// Persists auto-brightness preference to SharedPreferences.
class DisplayService {
  static const _keyAuto = 'display_auto_brightness';
  static const _keyReturnEnabled = 'return_to_home_enabled';
  static const _keyReturnDelay = 'return_to_home_delay_seconds';
  static const _backlightBase = '/sys/class/backlight';

  Future<Directory?> _backlightDir() async {
    final base = Directory(_backlightBase);
    if (!await base.exists()) return null;
    final dirs = await base.list().toList();
    if (dirs.isEmpty) return null;
    return dirs.first as Directory?;
  }

  Future<double> getBrightness() async {
    try {
      final dir = await _backlightDir();
      if (dir == null) return 1.0;
      final current = int.parse(await File('${dir.path}/brightness').readAsString().then((s) => s.trim()));
      final max     = int.parse(await File('${dir.path}/max_brightness').readAsString().then((s) => s.trim()));
      return (current / max).clamp(0.0, 1.0);
    } catch (_) {
      return 1.0;
    }
  }

  Future<void> setBrightness(double value) async {
    try {
      final dir = await _backlightDir();
      if (dir == null) return;
      final max     = int.parse(await File('${dir.path}/max_brightness').readAsString().then((s) => s.trim()));
      final target  = (value.clamp(0.0, 1.0) * max).round();
      await File('${dir.path}/brightness').writeAsString('$target');
    } catch (_) {}
  }

  Future<bool> getAutoBrightness() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAuto) ?? false;
  }

  Future<void> setAutoBrightness(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAuto, value);
  }

  Future<bool> getReturnToHome() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyReturnEnabled) ?? true;
  }

  Future<void> setReturnToHome(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyReturnEnabled, value);
  }

  Future<int> getReturnDelay() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyReturnDelay) ?? 300;
  }

  Future<void> setReturnDelay(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyReturnDelay, seconds);
  }

  Future<DisplaySpecs> getSpecs() async {
    try {
      final raw = await File('/sys/class/graphics/fb0/virtual_size').readAsString();
      final parts = raw.trim().split(',');
      if (parts.length == 2) {
        return DisplaySpecs(
          width: int.tryParse(parts[0]),
          height: int.tryParse(parts[1]),
        );
      }
    } catch (_) {}
    return const DisplaySpecs();
  }
}
