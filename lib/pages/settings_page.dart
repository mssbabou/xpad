import 'package:flutter/material.dart';
import 'package:xpad/app/theme.dart';
import 'package:xpad/pages/settings/debug_settings_page.dart';
import 'package:xpad/pages/settings/display_settings_page.dart';
import 'package:xpad/pages/settings/general_settings_page.dart';
import 'package:xpad/pages/settings/hue_settings_page.dart';
import 'package:xpad/pages/settings/octoprint_settings_page.dart';
import 'package:xpad/pages/settings/wifi_settings_page.dart';

class SettingsPage extends StatelessWidget {
  final ValueNotifier<bool> showPerfOverlay;

  const SettingsPage({
    super.key,
    required this.showPerfOverlay,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _Item(
        icon: Icons.tune_rounded,
        label: 'General',
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const GeneralSettingsPage())),
      ),
      _Item(
        icon: Icons.wifi_rounded,
        label: 'Wi-Fi',
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const WifiSettingsPage())),
      ),
      _Item(
        icon: Icons.print_rounded,
        label: 'OctoPrint',
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const OctoPrintSettingsPage())),
      ),
      _Item(
        icon: Icons.lightbulb_rounded,
        label: 'Philips Hue',
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const HueSettingsPage())),
      ),
      _Item(
        icon: Icons.brightness_medium_rounded,
        label: 'Display',
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const DisplaySettingsPage())),
      ),
      _Item(
        icon: Icons.code_rounded,
        label: 'Developer Menu',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DebugSettingsPage(showPerfOverlay: showPerfOverlay),
          ),
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: bg,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, thickness: 1, color: border, indent: 56),
                  _SettingsItem(item: items[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Item {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Item({required this.icon, required this.label, required this.onTap});
}

class _SettingsItem extends StatelessWidget {
  final _Item item;
  const _SettingsItem({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(item.icon, color: textLo, size: 20),
            const SizedBox(width: 16),
            Text(
              item.label,
              style: const TextStyle(
                color: textHi,
                fontSize: 16,
                fontWeight: FontWeight.w400,
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
