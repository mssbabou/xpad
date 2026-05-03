import 'package:flutter/material.dart';
import 'package:xpad/app/app_state.dart';
import 'package:xpad/app/theme.dart';
import 'package:xpad/widgets/settings_card.dart';

class OctoPrintSettingsPage extends StatefulWidget {
  const OctoPrintSettingsPage({super.key});

  @override
  State<OctoPrintSettingsPage> createState() => _OctoPrintSettingsPageState();
}

class _OctoPrintSettingsPageState extends State<OctoPrintSettingsPage> {
  late final TextEditingController _urlCtrl;
  late final TextEditingController _keyCtrl;
  late final FocusNode _urlFocus;
  late final FocusNode _keyFocus;
  String? _statusMessage;
  bool _statusOk = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: octoprintService.baseUrl);
    _keyCtrl = TextEditingController();
    _urlFocus = FocusNode();
    _keyFocus = FocusNode();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    _urlFocus.dispose();
    _keyFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await octoprintService.saveConfig(_urlCtrl.text.trim(), _keyCtrl.text.trim());
    if (mounted) setState(() { _statusMessage = 'Saved'; _statusOk = true; });
  }

  Future<void> _test() async {
    setState(() { _testing = true; _statusMessage = null; });
    final result = await octoprintService.testConnection(
      _urlCtrl.text.trim(),
      _keyCtrl.text.trim(),
    );
    if (!mounted) return;
    result.when(
      success: (v) => setState(() { _testing = false; _statusMessage = 'Connected — $v'; _statusOk = true; }),
      failure: (e) => setState(() { _testing = false; _statusMessage = e.message; _statusOk = false; }),
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
        title: const Text('OctoPrint',
            style: TextStyle(color: textHi, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsCard(
              label: 'SERVER',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Field(controller: _urlCtrl, focusNode: _urlFocus, hint: 'http://octopi.local'),
                  const SizedBox(height: 10),
                  const Text(
                    'OctoPrint URL — include http:// and no trailing slash',
                    style: TextStyle(color: textLo, fontSize: 11, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SettingsCard(
              label: 'API KEY',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Field(controller: _keyCtrl, focusNode: _keyFocus, hint: 'Paste API key', obscure: true),
                  const SizedBox(height: 10),
                  const Text(
                    'Found in OctoPrint → Settings → API → Global API Key',
                    style: TextStyle(color: textLo, fontSize: 11, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'SAVE',
                    filled: true,
                    onTap: _save,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _testing
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: accent, strokeWidth: 2),
                          ),
                        )
                      : _ActionButton(
                          label: 'TEST CONNECTION',
                          filled: false,
                          onTap: _test,
                        ),
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
  final bool obscure;
  const _Field({
    required this.controller,
    required this.focusNode,
    required this.hint,
    this.obscure = false,
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
      keyboardService.show(widget.controller, widget.focusNode,
          obscure: widget.obscure);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: widget.obscure,
      style:
          const TextStyle(color: textHi, fontSize: 15, fontWeight: FontWeight.w400),
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
