import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:xpad/app/app_state.dart';
import 'package:xpad/app/theme.dart';
import 'package:xpad/widgets/dash_card.dart';

class DebugPage extends StatelessWidget {
  final VoidCallback onToggleOverlay;
  final bool showPerfOverlay;

  const DebugPage({
    super.key,
    required this.onToggleOverlay,
    required this.showPerfOverlay,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: DashCard(
                    label: 'Performance',
                    child: _PerfCard(
                      showPerfOverlay: showPerfOverlay,
                      onToggle: onToggleOverlay,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DashCard(label: 'System Info', child: const _InfoCard()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: DashCard(label: 'Data', child: _DataRefreshCard()),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DashCard(label: 'Control', child: _ControlCard()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Performance overlay toggle ────────────────────────────────────────────────

class _PerfCard extends StatelessWidget {
  final bool showPerfOverlay;
  final VoidCallback onToggle;
  const _PerfCard({required this.showPerfOverlay, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: onToggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: showPerfOverlay ? accent.withValues(alpha: 0.12) : bg,
              border: Border.all(
                color: showPerfOverlay ? accent : border,
                width: 2,
              ),
            ),
            child: Icon(
              Icons.speed_rounded,
              size: 32,
              color: showPerfOverlay ? accent : textLo,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          showPerfOverlay ? 'ON' : 'OFF',
          style: TextStyle(
            color: showPerfOverlay ? accent : textLo,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        const Text('Overlay', style: TextStyle(color: textLo, fontSize: 11)),
      ],
    );
  }
}

// ── System info ───────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard();

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
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(label: 'Version', value: kAppVersion),
        _InfoRow(label: 'Build', value: kReleaseMode ? 'Release' : 'Debug'),
        FutureBuilder<String>(
          future: _getIp(),
          builder: (_, snap) => _InfoRow(label: 'IP', value: snap.data ?? '…'),
        ),
      ],
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
        Text(label,
            style: const TextStyle(
                color: textLo, fontSize: 10, letterSpacing: 1.0, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text(value,
            style: const TextStyle(color: textHi, fontSize: 16, fontWeight: FontWeight.w400)),
      ],
    );
  }
}

// ── Weather + Air Quality force-refresh ───────────────────────────────────────

class _DataRefreshCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _RefreshButton(
          icon: Icons.cloud_sync_rounded,
          label: 'Weather',
          onRefresh: () async {
            weather.clearCache();
            await weather.getCurrentWeather(forceRefresh: true);
            return null;
          },
          snackLabel: 'Weather refreshed',
        ),
        _RefreshButton(
          icon: Icons.air_rounded,
          label: 'Air Quality',
          onRefresh: () async {
            airQuality.clearCache();
            final result = await airQuality.getCurrentAirQuality(forceRefresh: true);
            return result.when(
              success: (data) => 'AQI ${data.europeanAqi}',
              failure: (_) => null,
            );
          },
          snackLabel: 'Air quality refreshed',
        ),
      ],
    );
  }
}

class _RefreshButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Future<String?> Function() onRefresh;
  final String snackLabel;

  const _RefreshButton({
    required this.icon,
    required this.label,
    required this.onRefresh,
    required this.snackLabel,
  });

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    final extra = await widget.onRefresh();
    if (mounted) {
      setState(() => _refreshing = false);
      final label = extra != null ? '${widget.snackLabel} — $extra' : widget.snackLabel;
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _refreshing ? null : _refresh,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bg,
              border: Border.all(color: border, width: 2),
            ),
            child: _refreshing
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: accent, strokeWidth: 2),
                  )
                : Icon(widget.icon, size: 32, color: textLo),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.label,
          style: const TextStyle(color: textLo, fontSize: 11, fontWeight: FontWeight.w400),
        ),
      ],
    );
  }
}

// ── System control (quit / reboot / shutdown) ─────────────────────────────────

class _ControlCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Icon(icon, color: accent, size: 20),
            const SizedBox(width: 12),
            Text(label,
                style: const TextStyle(
                    color: accent, fontSize: 15, fontWeight: FontWeight.w400)),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, color: accent, size: 20),
          ],
        ),
      ),
    );
  }
}
