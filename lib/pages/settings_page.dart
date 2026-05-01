import 'package:flutter/material.dart';
import 'package:xpad/app/theme.dart';
import 'package:xpad/pages/settings/debug_settings_page.dart';
import 'package:xpad/pages/settings/general_settings_page.dart';
import 'package:xpad/pages/settings/octoprint_settings_page.dart';
import 'package:xpad/pages/settings/wifi_settings_page.dart';

class SettingsPage extends StatelessWidget {
  final VoidCallback onToggleOverlay;
  final bool showPerfOverlay;

  const SettingsPage({
    super.key,
    required this.onToggleOverlay,
    required this.showPerfOverlay,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 12),
          _SettingsItem(
            label: 'General',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GeneralSettingsPage()),
            ),
          ),
          _SettingsItem(
            label: 'Wi-Fi',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WifiSettingsPage()),
            ),
          ),
          _SettingsItem(
            label: 'OctoPrint',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OctoPrintSettingsPage()),
            ),
          ),
          _SettingsItem(
            label: 'Developer Menu',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DebugSettingsPage(
                  onToggleOverlay: onToggleOverlay,
                  showPerfOverlay: showPerfOverlay,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: textHi,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, color: textLo, size: 20),
          ],
        ),
      ),
    );
  }
}
