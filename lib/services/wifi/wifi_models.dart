class WifiNetwork {
  final String ssid;
  final int signal;
  final String security;
  final bool isConnected;

  const WifiNetwork({
    required this.ssid,
    required this.signal,
    required this.security,
    required this.isConnected,
  });

  bool get isOpen => security.isEmpty || security == '--';
}

class WifiConnectionInfo {
  final String ssid;
  final String ipAddress;
  final String gateway;
  final String dns;
  final String security;
  final int signal;

  const WifiConnectionInfo({
    required this.ssid,
    required this.ipAddress,
    required this.gateway,
    required this.dns,
    required this.security,
    required this.signal,
  });
}

class WifiState {
  final bool hasAdapter;
  final bool enabled;
  final List<WifiNetwork> networks;

  const WifiState({
    required this.hasAdapter,
    required this.enabled,
    required this.networks,
  });

  WifiNetwork? get connected =>
      networks.where((n) => n.isConnected).firstOrNull;

  List<WifiNetwork> get available =>
      networks.where((n) => !n.isConnected).toList();
}
