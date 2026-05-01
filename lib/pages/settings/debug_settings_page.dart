import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:xpad/app/app_state.dart';
import 'package:xpad/app/theme.dart';
import 'package:xpad/widgets/app_toggle.dart';
import 'package:xpad/widgets/settings_card.dart';

class DebugSettingsPage extends StatelessWidget {
  final VoidCallback onToggleOverlay;
  final bool showPerfOverlay;

  const DebugSettingsPage({
    super.key,
    required this.onToggleOverlay,
    required this.showPerfOverlay,
  });

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
          'Developer Menu',
          style: TextStyle(color: textHi, fontWeight: FontWeight.w600),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoCard(),
            const SizedBox(height: 16),
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _OverlayCard(
                      showPerfOverlay: showPerfOverlay,
                      onToggle: onToggleOverlay,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: _WeatherCard()),
                  const SizedBox(width: 16),
                  Expanded(child: _AirQualityCard()),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _ControlCard(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ── System info ───────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  Future<String> _getIp() async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (_) {}
    return 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      label: 'System',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _Stat(label: 'Version', value: kAppVersion),
          const SizedBox(width: 36),
          _Stat(label: 'Build', value: kReleaseMode ? 'Release' : 'Debug'),
          const SizedBox(width: 36),
          FutureBuilder<String>(
            future: _getIp(),
            builder: (_, snap) => _Stat(label: 'IP', value: snap.data ?? '…'),
          ),
        ],
      ),
    );
  }
}

// ── Performance overlay toggle ────────────────────────────────────────────────

class _OverlayCard extends StatelessWidget {
  final bool showPerfOverlay;
  final VoidCallback onToggle;
  const _OverlayCard({required this.showPerfOverlay, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      label: 'Overlay',
      child: Row(
        children: [
          const Text(
            'Performance',
            style: TextStyle(color: textHi, fontSize: 16, fontWeight: FontWeight.w300),
          ),
          const Spacer(),
          AppToggle(value: showPerfOverlay, onChanged: (_) => onToggle()),
        ],
      ),
    );
  }
}

// ── Weather force-refresh ─────────────────────────────────────────────────────

class _WeatherCard extends StatefulWidget {
  @override
  State<_WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<_WeatherCard> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    weather.clearCache();
    await weather.getCurrentWeather(forceRefresh: true);
    if (mounted) {
      setState(() => _refreshing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Weather refreshed'),
        backgroundColor: textHi,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      label: 'Weather',
      child: GestureDetector(
        onTap: _refreshing ? null : _refresh,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (_refreshing)
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(color: accent, strokeWidth: 2),
              )
            else
              Icon(
                Icons.cloud_sync_rounded,
                size: 36,
                color: textHi,
              ),
            const SizedBox(height: 8),
            const Text(
              'Refresh',
              style: TextStyle(color: textLo, fontSize: 12, letterSpacing: 0.8),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Air quality force-refresh ─────────────────────────────────────────────────

class _AirQualityCard extends StatefulWidget {
  @override
  State<_AirQualityCard> createState() => _AirQualityCardState();
}

class _AirQualityCardState extends State<_AirQualityCard> {
  bool _refreshing = false;
  String? _lastAqi;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    airQuality.clearCache();
    final result = await airQuality.getCurrentAirQuality(forceRefresh: true);
    if (mounted) {
      final label = result.when(
        success: (data) => 'AQI ${data.europeanAqi} — ${data.level.label}',
        failure: (e) => e.message,
      );
      setState(() {
        _refreshing = false;
        _lastAqi = label;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(label),
        backgroundColor: textHi,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      label: 'Air Quality',
      child: GestureDetector(
        onTap: _refreshing ? null : _refresh,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (_refreshing)
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(color: accent, strokeWidth: 2),
              )
            else
              Icon(Icons.air_rounded, size: 36, color: textHi),
            const SizedBox(height: 8),
            Text(
              _lastAqi ?? 'Refresh',
              style: const TextStyle(color: textLo, fontSize: 12, letterSpacing: 0.8),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── System control (quit / reboot / shutdown) ─────────────────────────────────

class _ControlCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      label: 'Control',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlButton(
            icon: Icons.close_rounded,
            label: 'Quit',
            onTap: () => _confirm(context,
              title: 'Quit App?',
              message: 'The application will close.',
              confirmLabel: 'Quit',
              onConfirm: () => exit(0),
            ),
          ),
          _ControlButton(
            icon: Icons.restart_alt_rounded,
            label: 'Reboot',
            onTap: () => _confirm(context,
              title: 'Reboot?',
              message: 'The Raspberry Pi will restart.',
              confirmLabel: 'Reboot',
              onConfirm: () => Process.run('sudo', ['reboot']),
            ),
          ),
          _ControlButton(
            icon: Icons.power_settings_new_rounded,
            label: 'Shutdown',
            onTap: () => _confirm(context,
              title: 'Shutdown?',
              message: 'The Raspberry Pi will power off.',
              confirmLabel: 'Shutdown',
              onConfirm: () => Process.run('sudo', ['shutdown', '-h', 'now']),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required VoidCallback onConfirm,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: const TextStyle(color: textHi, fontWeight: FontWeight.w600)),
        content: Text(message, style: const TextStyle(color: textLo)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: textLo)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: accent),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    if (confirmed == true) onConfirm();
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ControlButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 28, color: accent),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: textHi, fontSize: 12, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}

// ── Shared stat widget ────────────────────────────────────────────────────────

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

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
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
