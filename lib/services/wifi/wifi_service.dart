import 'dart:io';
import 'wifi_models.dart';

class WifiService {
  Future<bool> isEnabled() async {
    try {
      final r = await Process.run('nmcli', ['radio', 'wifi']);
      return r.stdout.toString().trim() == 'enabled';
    } catch (_) {
      return false;
    }
  }

  Future<void> setEnabled(bool on) async {
    await Process.run('nmcli', ['radio', 'wifi', on ? 'on' : 'off']);
  }

  Future<WifiState> scan() async {
    final hasAdapter = await _wifiInterface() != null;
    if (!hasAdapter) return const WifiState(hasAdapter: false, enabled: false, networks: []);

    final enabled = await isEnabled();
    if (!enabled) return const WifiState(hasAdapter: true, enabled: false, networks: []);

    final r = await Process.run('nmcli', [
      '-t', '-f', 'ACTIVE,SSID,SIGNAL,SECURITY',
      'dev', 'wifi',
    ]);

    final seen = <String>{};
    final networks = <WifiNetwork>[];
    for (final line in r.stdout.toString().split('\n')) {
      final parts = line.split(':');
      if (parts.length < 4) continue;
      final active = parts[0] == 'yes';
      final ssid = parts[1].trim();
      final signal = int.tryParse(parts[2]) ?? 0;
      final security = parts.sublist(3).join(':').trim();
      if (ssid.isEmpty || (!active && !seen.add(ssid))) continue;
      if (active) seen.add(ssid);
      networks.add(WifiNetwork(
        ssid: ssid,
        signal: signal,
        security: security,
        isConnected: active,
      ));
    }

    networks.sort((a, b) {
      if (a.isConnected != b.isConnected) return a.isConnected ? -1 : 1;
      return b.signal.compareTo(a.signal);
    });

    return WifiState(hasAdapter: true, enabled: true, networks: networks);
  }

  Future<WifiConnectionInfo?> getConnectionInfo() async {
    final state = await scan();
    final connected = state.connected;
    if (connected == null) return null;

    // Try wlan0 first, fall back to first wifi device
    String? iface = await _wifiInterface();
    if (iface == null) return null;

    final r = await Process.run('nmcli', [
      '-t', '-f', 'IP4.ADDRESS,IP4.GATEWAY,IP4.DNS',
      'dev', 'show', iface,
    ]);

    String ip = 'N/A', gateway = 'N/A', dns = 'N/A';
    for (final line in r.stdout.toString().split('\n')) {
      if (line.startsWith('IP4.ADDRESS')) {
        final val = line.split(':').sublist(1).join(':').trim();
        ip = val.split('/').first;
      } else if (line.startsWith('IP4.GATEWAY')) {
        gateway = line.split(':').sublist(1).join(':').trim();
      } else if (line.startsWith('IP4.DNS[1]')) {
        dns = line.split(':').sublist(1).join(':').trim();
      }
    }

    return WifiConnectionInfo(
      ssid: connected.ssid,
      ipAddress: ip,
      gateway: gateway,
      dns: dns,
      security: connected.security,
      signal: connected.signal,
    );
  }

  Future<String?> _wifiInterface() async {
    try {
      final r = await Process.run('nmcli', ['-t', '-f', 'DEVICE,TYPE', 'dev']);
      for (final line in r.stdout.toString().split('\n')) {
        final parts = line.split(':');
        if (parts.length >= 2 && parts[1].trim() == 'wifi') {
          return parts[0].trim();
        }
      }
    } catch (_) {}
    return null;
  }
}
