import 'package:flutter/material.dart';
import 'package:xpad/app/app_state.dart';
import 'package:xpad/app/theme.dart';
import 'package:xpad/services/display/display_service.dart';
import 'package:xpad/widgets/app_toggle.dart';
import 'package:xpad/widgets/settings_card.dart';

class DisplaySettingsPage extends StatefulWidget {
  const DisplaySettingsPage({super.key});

  @override
  State<DisplaySettingsPage> createState() => _DisplaySettingsPageState();
}

class _DisplaySettingsPageState extends State<DisplaySettingsPage> {
  double _brightness = 1.0;
  bool _auto = false;
  DisplaySpecs? _specs;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final brightness = await displayService.getBrightness();
    final auto       = await displayService.getAutoBrightness();
    final specs      = await displayService.getSpecs();
    if (!mounted) return;
    setState(() {
      _brightness = brightness;
      _auto       = auto;
      _specs      = specs;
      _loaded     = true;
    });
  }

  Future<void> _setBrightness(double value) async {
    setState(() => _brightness = value);
    await displayService.setBrightness(value);
  }

  Future<void> _setAuto(bool value) async {
    setState(() => _auto = value);
    await displayService.setAutoBrightness(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: textHi),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Display',
          style: TextStyle(color: textHi, fontWeight: FontWeight.w600),
        ),
      ),
      body: _loaded
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SettingsCard(
                    label: 'Brightness',
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.brightness_low_rounded, color: textLo, size: 20),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: _auto ? border : accent,
                                  inactiveTrackColor: border,
                                  thumbColor: _auto ? textLo : accent,
                                  overlayColor: accent.withValues(alpha: 0.12),
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                                ),
                                child: Slider(
                                  value: _brightness,
                                  onChanged: _auto ? null : _setBrightness,
                                ),
                              ),
                            ),
                            const Icon(Icons.brightness_high_rounded, color: textHi, size: 20),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Text(
                              'Auto brightness',
                              style: TextStyle(color: textHi, fontSize: 15, fontWeight: FontWeight.w300),
                            ),
                            const Spacer(),
                            AppToggle(value: _auto, onChanged: _setAuto),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SettingsCard(
                    label: 'Display',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Spec(
                          label: 'Resolution',
                          value: _specs?.width != null && _specs?.height != null
                              ? '${_specs!.width} × ${_specs!.height}'
                              : '—',
                        ),
                        const SizedBox(height: 14),
                        _Spec(
                          label: 'Refresh rate',
                          value: _specs?.refreshRate != null ? '${_specs!.refreshRate} Hz' : '—',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            )
          : const Center(child: CircularProgressIndicator(color: accent, strokeWidth: 2)),
    );
  }
}

class _Spec extends StatelessWidget {
  final String label;
  final String value;
  const _Spec({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(color: textLo, fontSize: 14, fontWeight: FontWeight.w400),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(color: textHi, fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
