import 'package:flutter/material.dart';
import 'package:xpad/app/app_state.dart';
import 'package:xpad/app/theme.dart';
import 'package:xpad/widgets/settings_card.dart';

class HueSettingsPage extends StatefulWidget {
  const HueSettingsPage({super.key});

  @override
  State<HueSettingsPage> createState() => _HueSettingsPageState();
}

class _HueSettingsPageState extends State<HueSettingsPage> {
  late final TextEditingController _ipCtrl;
  late final TextEditingController _usernameCtrl;
  late final FocusNode _ipFocus;
  late final FocusNode _usernameFocus;
  String? _statusMessage;
  bool _statusOk = false;
  bool _linking = false;
  bool _discovering = false;

  @override
  void initState() {
    super.initState();
    _ipCtrl = TextEditingController(text: hueService.bridgeIp);
    _usernameCtrl = TextEditingController(text: hueService.username);
    _ipFocus = FocusNode();
    _usernameFocus = FocusNode();
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _usernameCtrl.dispose();
    _ipFocus.dispose();
    _usernameFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await hueService.saveConfig(_ipCtrl.text.trim(), _usernameCtrl.text.trim());
    if (mounted) setState(() { _statusMessage = 'Saved'; _statusOk = true; });
  }

  Future<void> _discover() async {
    setState(() { _discovering = true; _statusMessage = null; });
    final result = await hueService.discoverBridges();
    if (!mounted) return;
    result.when(
      success: (ips) {
        _ipCtrl.text = ips.first;
        setState(() {
          _discovering = false;
          _statusMessage = ips.length == 1
              ? 'Found bridge at ${ips.first}'
              : 'Found ${ips.length} bridges — using ${ips.first}';
          _statusOk = true;
        });
      },
      failure: (e) => setState(() {
        _discovering = false;
        _statusMessage = e.message;
        _statusOk = false;
      }),
    );
  }

  Future<void> _link() async {
    setState(() { _linking = true; _statusMessage = null; });
    final result = await hueService.linkBridge(_ipCtrl.text.trim());
    if (!mounted) return;
    result.when(
      success: (username) {
        _usernameCtrl.text = username;
        setState(() {
          _linking = false;
          _statusMessage = 'Linked — username saved';
          _statusOk = true;
        });
      },
      failure: (e) => setState(() {
        _linking = false;
        _statusMessage = e.message;
        _statusOk = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textHi, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Philips Hue',
            style: TextStyle(color: textHi, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsCard(
              label: 'BRIDGE IP',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Field(controller: _ipCtrl, focusNode: _ipFocus, hint: '192.168.1.x'),
                  const SizedBox(height: 10),
                  const Text(
                    'Local IP address of your Hue Bridge',
                    style: TextStyle(color: textLo, fontSize: 11, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SettingsCard(
              label: 'USERNAME',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Field(controller: _usernameCtrl, focusNode: _usernameFocus, hint: 'Auto-filled after linking'),
                  const SizedBox(height: 10),
                  const Text(
                    'Press the button on your Hue Bridge, then tap Link to generate automatically',
                    style: TextStyle(color: textLo, fontSize: 11, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(label: 'SAVE', filled: true, onTap: _save),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _discovering
                      ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: accent, strokeWidth: 2)))
                      : _ActionButton(label: 'DISCOVER', filled: false, onTap: _discover),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _linking
                      ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: accent, strokeWidth: 2)))
                      : _ActionButton(label: 'LINK', filled: false, onTap: _link),
                ),
              ],
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _statusMessage!,
                style: TextStyle(
                  color: _statusOk ? const Color(0xFF1DB954) : const Color(0xFFE53935),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Field extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;

  const _Field({
    required this.controller,
    required this.focusNode,
    required this.hint,
  });

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
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      style: const TextStyle(color: textHi, fontSize: 15, fontWeight: FontWeight.w400),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: const TextStyle(color: textLo, fontSize: 15),
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _ActionButton({required this.label, required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: filled ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: filled ? null : Border.all(color: accent),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: filled ? Colors.white : accent,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}
