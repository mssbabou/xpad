import 'dart:async';
import 'package:flutter/material.dart';
import 'package:xpad/app/theme.dart';
import 'package:xpad/services/wifi/wifi_models.dart';
import 'package:xpad/services/wifi/wifi_service.dart';
import 'package:xpad/widgets/app_toggle.dart';
import 'package:xpad/widgets/settings_card.dart';

final _wifi = WifiService();

class WifiSettingsPage extends StatefulWidget {
  const WifiSettingsPage({super.key});

  @override
  State<WifiSettingsPage> createState() => _WifiSettingsPageState();
}

class _WifiSettingsPageState extends State<WifiSettingsPage> {
  WifiState? _state;
  bool _loading = true;
  bool _toggling = false;
  bool _scanning = false;
  Timer? _autoRefresh;

  @override
  void initState() {
    super.initState();
    _load();
    _autoRefresh = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!_scanning && !_toggling) _refresh();
    });
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final state = await _wifi.scan();
    if (mounted) setState(() { _state = state; _loading = false; });
  }

  Future<void> _refresh() async {
    setState(() => _scanning = true);
    final state = await _wifi.scan();
    if (mounted) setState(() { _state = state; _scanning = false; });
  }

  Future<void> _toggle() async {
    final current = _state?.enabled ?? false;
    setState(() => _toggling = true);
    await _wifi.setEnabled(!current);
    await Future.delayed(const Duration(milliseconds: 600));
    final state = await _wifi.scan();
    if (mounted) setState(() { _state = state; _toggling = false; });
  }

  void _showInfo() async {
    final info = await _wifi.getConnectionInfo();
    if (!mounted || info == null) return;
    showDialog<void>(
      context: context,
      builder: (_) => _InfoDialog(info: info),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: textHi),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Wi-Fi',
          style: TextStyle(color: textHi, fontWeight: FontWeight.w600),
        ),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: accent, strokeWidth: 2))
          : _state!.hasAdapter
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ToggleCard(
                        enabled: _state!.enabled,
                        loading: _toggling,
                        onTap: _toggle,
                      ),
                      if (_state!.enabled) ...[
                        const SizedBox(height: 16),
                        _ConnectedCard(
                          network: _state!.connected,
                          onInfo: _showInfo,
                        ),
                        const SizedBox(height: 16),
                        _AvailableCard(
                          networks: _state!.available,
                          scanning: _scanning,
                          onRefresh: _refresh,
                        ),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                )
              : const Center(
                  child: _NoAdapterMessage(),
                ),
    );
  }
}

// ── Toggle ────────────────────────────────────────────────────────────────────

class _ToggleCard extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;
  const _ToggleCard({required this.enabled, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      label: 'Wi-Fi',
      child: Row(
        children: [
          const Text(
            'Wireless',
            style: TextStyle(color: textHi, fontSize: 16, fontWeight: FontWeight.w300),
          ),
          const Spacer(),
          loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: accent, strokeWidth: 2),
                )
              : AppToggle(
                  value: enabled,
                  onChanged: (_) => onTap(),
                ),
        ],
      ),
    );
  }
}

// ── Connected network ─────────────────────────────────────────────────────────

class _ConnectedCard extends StatelessWidget {
  final WifiNetwork? network;
  final VoidCallback onInfo;
  const _ConnectedCard({required this.network, required this.onInfo});

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      label: 'Connected',
      trailing: network == null
          ? null
          : GestureDetector(
              onTap: onInfo,
              child: const Text(
                'INFO',
                style: TextStyle(
                  color: accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ),
      child: network == null
          ? const Text(
              'Not connected',
              style: TextStyle(color: textLo, fontSize: 16, fontWeight: FontWeight.w300),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    network!.ssid,
                    style: const TextStyle(
                      color: textHi,
                      fontSize: 28,
                      fontWeight: FontWeight.w200,
                      height: 1,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 16),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: _SignalBars(signal: network!.signal),
                ),
              ],
            ),
    );
  }
}

// ── Available networks ────────────────────────────────────────────────────────

class _AvailableCard extends StatelessWidget {
  final List<WifiNetwork> networks;
  final bool scanning;
  final VoidCallback onRefresh;
  const _AvailableCard({
    required this.networks,
    required this.scanning,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      label: 'Available',
      trailing: GestureDetector(
        onTap: scanning ? null : onRefresh,
        child: scanning
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(color: accent, strokeWidth: 1.5),
              )
            : const Text(
                'SCAN',
                style: TextStyle(
                  color: accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
      ),
      child: networks.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No networks found',
                style: TextStyle(color: textLo, fontSize: 14, fontWeight: FontWeight.w300),
              ),
            )
          : Column(
              children: [
                for (int i = 0; i < networks.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, color: border, thickness: 0.5),
                  _NetworkRow(network: networks[i]),
                ],
              ],
            ),
    );
  }
}

class _NetworkRow extends StatelessWidget {
  final WifiNetwork network;
  const _NetworkRow({required this.network});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              network.ssid,
              style: const TextStyle(
                color: textHi,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          if (!network.isOpen)
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Text(
                'WPA',
                style: TextStyle(color: textLo, fontSize: 10, letterSpacing: 0.8),
              ),
            ),
          _SignalBars(signal: network.signal),
        ],
      ),
    );
  }
}

// ── Signal bars ───────────────────────────────────────────────────────────────

class _SignalBars extends StatelessWidget {
  final int signal;
  const _SignalBars({required this.signal});

  @override
  Widget build(BuildContext context) {
    final bars = signal >= 75 ? 4 : signal >= 50 ? 3 : signal >= 25 ? 2 : 1;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final active = i < bars;
        return Container(
          width: 4,
          height: 4 + (i * 3.5),
          margin: const EdgeInsets.only(left: 2),
          decoration: BoxDecoration(
            color: active ? textHi : textLo.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}

// ── Info dialog ───────────────────────────────────────────────────────────────

class _InfoDialog extends StatelessWidget {
  final WifiConnectionInfo info;
  const _InfoDialog({required this.info});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              info.ssid,
              style: const TextStyle(
                color: textHi,
                fontSize: 22,
                fontWeight: FontWeight.w300,
                height: 1,
              ),
            ),
            const SizedBox(height: 24),
            _InfoRow(label: 'IP Address', value: info.ipAddress),
            const SizedBox(height: 16),
            _InfoRow(label: 'Gateway', value: info.gateway),
            const SizedBox(height: 16),
            _InfoRow(label: 'DNS', value: info.dns),
            const SizedBox(height: 16),
            _InfoRow(label: 'Security', value: info.security.isEmpty ? 'Open' : info.security),
            const SizedBox(height: 16),
            _InfoRow(label: 'Signal', value: '${info.signal}%'),
            const SizedBox(height: 28),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Text(
                  'DONE',
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: textLo,
            fontSize: 10,
            letterSpacing: 1.0,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: textHi,
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ── No adapter message ────────────────────────────────────────────────────────

class _NoAdapterMessage extends StatelessWidget {
  const _NoAdapterMessage();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'No wireless adapter',
          style: const TextStyle(
            color: textHi,
            fontSize: 20,
            fontWeight: FontWeight.w300,
            height: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Wi-Fi device not found',
          style: const TextStyle(
            color: textLo,
            fontSize: 14,
            fontWeight: FontWeight.w300,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
