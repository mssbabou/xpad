import 'package:flutter/material.dart';
import 'package:xpad/app/app_state.dart';
import 'package:xpad/app/theme.dart';
import 'package:xpad/services/location/geocoding_api.dart';
import 'package:xpad/services/location/location_models.dart';
import 'package:xpad/widgets/app_toggle.dart';
import 'package:xpad/widgets/settings_card.dart';

class GeneralSettingsPage extends StatefulWidget {
  const GeneralSettingsPage({super.key});

  @override
  State<GeneralSettingsPage> createState() => _GeneralSettingsPageState();
}

class _GeneralSettingsPageState extends State<GeneralSettingsPage> {
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _geocodingApi = GeocodingApi();

  bool _isManual = false;
  LocationData? _currentLocation;
  bool _saving = false;
  bool _resetting = false;
  String? _errorMessage;
  String? _successMessage;
  bool _returnEnabled = true;
  int _returnDelaySeconds = 300;
  bool _returnConfigLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentState();
  }

  Future<void> _loadCurrentState() async {
    final isManual = await locationService.isManualOverride();
    final result = await locationService.getLocation();
    final returnEnabled = await displayService.getReturnToHome();
    final returnDelay = await displayService.getReturnDelay();
    if (!mounted) return;
    setState(() {
      _isManual = isManual;
      _returnEnabled = returnEnabled;
      _returnDelaySeconds = returnDelay;
      _returnConfigLoaded = true;
      result.when(
        success: (loc) {
          _currentLocation = loc;
          _cityController.text = loc.city;
          _countryController.text = loc.country;
        },
        failure: (_) {},
      );
    });
  }

  Future<void> _save() async {
    final city = _cityController.text.trim();
    final country = _countryController.text.trim();
    if (city.isEmpty) {
      setState(() => _errorMessage = 'Please enter a city name.');
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final result = await _geocodingApi.search(city, country: country.isEmpty ? null : country);

    if (!mounted) return;

    result.when(
      success: (loc) async {
        await locationService.setManualLocation(loc);
        weather.updateLocation(loc.latitude, loc.longitude);
        airQuality.updateLocation(loc.latitude, loc.longitude);
        if (mounted) {
          setState(() {
            _saving = false;
            _isManual = true;
            _currentLocation = loc;
            _cityController.text = loc.city;
            _countryController.text = loc.country;
            _successMessage = 'Location set to ${loc.city}, ${loc.country}.';
          });
        }
      },
      failure: (error) {
        setState(() {
          _saving = false;
          _errorMessage = error.message;
        });
      },
    );
  }

  Future<void> _resetToAuto() async {
    setState(() {
      _resetting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    await locationService.clearManualLocation();
    final result = await locationService.getLocation(forceRefresh: true);

    if (!mounted) return;

    result.when(
      success: (loc) {
        weather.updateLocation(loc.latitude, loc.longitude);
        airQuality.updateLocation(loc.latitude, loc.longitude);
        setState(() {
          _resetting = false;
          _isManual = false;
          _currentLocation = loc;
          _cityController.text = loc.city;
          _countryController.text = loc.country;
          _successMessage = 'Reset to auto-detected: ${loc.city}, ${loc.country}.';
        });
      },
      failure: (error) {
        setState(() {
          _resetting = false;
          _errorMessage = error.message;
        });
      },
    );
  }

  Future<void> _setReturnEnabled(bool value) async {
    setState(() => _returnEnabled = value);
    await displayService.setReturnToHome(value);
  }

  Future<void> _setReturnDelay(int seconds) async {
    setState(() => _returnDelaySeconds = seconds);
    await displayService.setReturnDelay(seconds);
  }

  @override
  void dispose() {
    _cityController.dispose();
    _countryController.dispose();
    _geocodingApi.dispose();
    super.dispose();
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_returnConfigLoaded)
              _ReturnToHomeCard(
                enabled: _returnEnabled,
                delaySeconds: _returnDelaySeconds,
                onToggle: _setReturnEnabled,
                onDelayChanged: _setReturnDelay,
              ),
            if (_returnConfigLoaded) const SizedBox(height: 20),
            _LocationCard(
              cityController: _cityController,
              countryController: _countryController,
              isManual: _isManual,
              currentLocation: _currentLocation,
              saving: _saving,
              resetting: _resetting,
              errorMessage: _errorMessage,
              successMessage: _successMessage,
              onSave: _save,
              onReset: _resetToAuto,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Return to home card ───────────────────────────────────────────────────────

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
                child: Text(
                  'Auto-return to dashboard',
                  style: TextStyle(color: textHi, fontSize: 15),
                ),
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

// ── Location card ─────────────────────────────────────────────────────────────

class _LocationCard extends StatelessWidget {
  final TextEditingController cityController;
  final TextEditingController countryController;
  final bool isManual;
  final LocationData? currentLocation;
  final bool saving;
  final bool resetting;
  final String? errorMessage;
  final String? successMessage;
  final VoidCallback onSave;
  final VoidCallback onReset;

  const _LocationCard({
    required this.cityController,
    required this.countryController,
    required this.isManual,
    required this.currentLocation,
    required this.saving,
    required this.resetting,
    required this.errorMessage,
    required this.successMessage,
    required this.onSave,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      label: 'Location',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (currentLocation != null) ...[
            Row(
              children: [
                Text(
                  '${currentLocation!.city}, ${currentLocation!.country}',
                  style: const TextStyle(
                    color: textHi,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isManual
                        ? accent.withValues(alpha: 0.15)
                        : textLo.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isManual ? 'Manual' : 'Auto',
                    style: TextStyle(
                      color: isManual ? accent : textLo,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          _Field(label: 'City', controller: cityController),
          const SizedBox(height: 12),
          _Field(label: 'Country', controller: countryController, hint: 'e.g. Germany'),
          const SizedBox(height: 20),
          Row(
            children: [
              _ActionButton(
                label: saving ? 'Saving…' : 'Save',
                busy: saving,
                onTap: saving || resetting ? null : onSave,
              ),
              if (isManual) ...[
                const SizedBox(width: 12),
                _ActionButton(
                  label: resetting ? 'Resetting…' : 'Reset to auto',
                  busy: resetting,
                  secondary: true,
                  onTap: saving || resetting ? null : onReset,
                ),
              ],
            ],
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 14),
            Text(
              errorMessage!,
              style: const TextStyle(color: Color(0xFFE05252), fontSize: 13),
            ),
          ],
          if (successMessage != null) ...[
            const SizedBox(height: 14),
            Text(
              successMessage!,
              style: const TextStyle(color: Color(0xFF52C07A), fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Text field ────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;

  const _Field({required this.label, required this.controller, this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: textLo,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: const TextStyle(color: textHi, fontSize: 15),
          cursorColor: accent,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: textLo),
            filled: true,
            fillColor: bg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: accent),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final bool busy;
  final bool secondary;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.busy,
    this.secondary = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.4 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: secondary ? Colors.transparent : accent,
            borderRadius: BorderRadius.circular(10),
            border: secondary ? Border.all(color: border) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: secondary ? textLo : Colors.white,
                  ),
                )
              else
                Text(
                  label,
                  style: TextStyle(
                    color: secondary ? textHi : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
