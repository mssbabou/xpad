import 'package:flutter/material.dart';
import 'package:xpad/app/app_state.dart';
import 'package:xpad/app/theme.dart';
import 'package:xpad/services/location/geocoding_api.dart';
import 'package:xpad/services/location/location_models.dart';
import 'package:xpad/widgets/settings_card.dart';

class LocationSettingsPage extends StatefulWidget {
  const LocationSettingsPage({super.key});

  @override
  State<LocationSettingsPage> createState() => _LocationSettingsPageState();
}

class _LocationSettingsPageState extends State<LocationSettingsPage> {
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _cityFocus = FocusNode();
  final _countryFocus = FocusNode();
  final _geocodingApi = GeocodingApi();

  bool _isManual = false;
  LocationData? _currentLocation;
  bool _saving = false;
  bool _resetting = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final isManual = await locationService.isManualOverride();
    final result = await locationService.getLocation();
    if (!mounted) return;
    setState(() {
      _isManual = isManual;
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
    setState(() { _saving = true; _errorMessage = null; _successMessage = null; });

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
        setState(() { _saving = false; _errorMessage = error.message; });
      },
    );
  }

  Future<void> _reset() async {
    setState(() { _resetting = true; _errorMessage = null; _successMessage = null; });

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
        setState(() { _resetting = false; _errorMessage = error.message; });
      },
    );
  }

  @override
  void dispose() {
    _cityController.dispose();
    _countryController.dispose();
    _cityFocus.dispose();
    _countryFocus.dispose();
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
          'Location',
          style: TextStyle(color: textHi, fontWeight: FontWeight.w600),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: SettingsCard(
          label: 'Location',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_currentLocation != null) ...[
                Row(
                  children: [
                    Text(
                      '${_currentLocation!.city}, ${_currentLocation!.country}',
                      style: const TextStyle(color: textHi, fontSize: 16, fontWeight: FontWeight.w400),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _isManual
                            ? accent.withValues(alpha: 0.15)
                            : textLo.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _isManual ? 'Manual' : 'Auto',
                        style: TextStyle(
                          color: _isManual ? accent : textLo,
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
              _Field(label: 'City', controller: _cityController, focusNode: _cityFocus),
              const SizedBox(height: 12),
              _Field(label: 'Country', controller: _countryController, focusNode: _countryFocus, hint: 'e.g. Germany'),
              const SizedBox(height: 20),
              Row(
                children: [
                  _ActionButton(
                    label: _saving ? 'Saving…' : 'Save',
                    busy: _saving,
                    onTap: _saving || _resetting ? null : _save,
                  ),
                  if (_isManual) ...[
                    const SizedBox(width: 12),
                    _ActionButton(
                      label: _resetting ? 'Resetting…' : 'Reset to auto',
                      busy: _resetting,
                      secondary: true,
                      onTap: _saving || _resetting ? null : _reset,
                    ),
                  ],
                ],
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Text(_errorMessage!, style: const TextStyle(color: Color(0xFFE05252), fontSize: 13)),
              ],
              if (_successMessage != null) ...[
                const SizedBox(height: 14),
                Text(_successMessage!, style: const TextStyle(color: Color(0xFF52C07A), fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final FocusNode focusNode;

  const _Field({required this.label, required this.controller, required this.focusNode, this.hint});

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (widget.focusNode.hasFocus) {
      keyboardService.show(widget.controller, widget.focusNode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: const TextStyle(color: textLo, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          style: const TextStyle(color: textHi, fontSize: 15),
          cursorColor: accent,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(color: textLo),
            filled: true,
            fillColor: bg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: accent)),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool busy;
  final bool secondary;
  final VoidCallback? onTap;

  const _ActionButton({required this.label, required this.busy, this.secondary = false, this.onTap});

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
                  child: CircularProgressIndicator(strokeWidth: 2, color: secondary ? textLo : Colors.white),
                )
              else
                Text(
                  label,
                  style: TextStyle(color: secondary ? textHi : Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
