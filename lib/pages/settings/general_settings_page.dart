import 'package:flutter/material.dart';
import 'package:xpad/app/app_state.dart';
import 'package:xpad/app/theme.dart';
import 'package:xpad/widgets/app_toggle.dart';
import 'package:xpad/widgets/settings_card.dart';

class GeneralSettingsPage extends StatefulWidget {
  const GeneralSettingsPage({super.key});

  @override
  State<GeneralSettingsPage> createState() => _GeneralSettingsPageState();
}

class _GeneralSettingsPageState extends State<GeneralSettingsPage> {
  bool _returnEnabled = true;
  int _returnDelaySeconds = 300;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await displayService.getReturnToHome();
    final delay = await displayService.getReturnDelay();
    if (!mounted) return;
    setState(() {
      _returnEnabled = enabled;
      _returnDelaySeconds = delay;
      _loaded = true;
    });
  }

  Future<void> _setEnabled(bool value) async {
    setState(() => _returnEnabled = value);
    await displayService.setReturnToHome(value);
  }

  Future<void> _setDelay(int seconds) async {
    setState(() => _returnDelaySeconds = seconds);
    await displayService.setReturnDelay(seconds);
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
          'General',
          style: TextStyle(color: textHi, fontWeight: FontWeight.w600),
        ),
        elevation: 0,
      ),
      body: _loaded
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _ReturnToHomeCard(
                enabled: _returnEnabled,
                delaySeconds: _returnDelaySeconds,
                onToggle: _setEnabled,
                onDelayChanged: _setDelay,
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _ReturnToHomeCard extends StatelessWidget {
  final bool enabled;
  final int delaySeconds;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onDelayChanged;

  const _ReturnToHomeCard({
    required this.enabled,
    required this.delaySeconds,
    required this.onToggle,
    required this.onDelayChanged,
  });

  static const _options = [30, 60, 120, 300, 600];
  static const _labels = ['30s', '1m', '2m', '5m', '10m'];

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      label: 'Return to Home',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Auto-return to dashboard', style: TextStyle(color: textHi, fontSize: 15)),
              ),
              AppToggle(value: enabled, onChanged: onToggle),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                for (int i = 0; i < _options.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _DelayChip(
                    label: _labels[i],
                    selected: delaySeconds == _options[i],
                    onTap: () => onDelayChanged(_options[i]),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DelayChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DelayChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? accent : border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : textLo,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
