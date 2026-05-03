import 'dart:async';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xpad/app/app_state.dart';
import 'package:xpad/app/theme.dart';

class SpotifySettingsPage extends StatefulWidget {
  const SpotifySettingsPage({super.key});

  @override
  State<SpotifySettingsPage> createState() => _SpotifySettingsPageState();
}

class _SpotifySettingsPageState extends State<SpotifySettingsPage> {
  late final TextEditingController _clientIdCtrl;
  late final TextEditingController _refreshTokenCtrl;
  bool _connecting = false;
  bool _showManual = false;
  bool _tokenCopied = false;
  bool _tokenImported = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _clientIdCtrl =
        TextEditingController(text: spotifyService.credentials.clientId);
    _refreshTokenCtrl = TextEditingController();
    _checkDropFile();
  }

  @override
  void dispose() {
    _clientIdCtrl.dispose();
    _refreshTokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkDropFile() async {
    final imported = await spotifyService.importDropFile();
    if (imported && mounted) {
      setState(() => _tokenImported = true);
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) setState(() => _tokenImported = false);
    }
  }

  Future<void> _save() async {
    final id = _clientIdCtrl.text.trim();
    await spotifyService.saveClientId(id);
    if (mounted) setState(() {});
  }

  Future<void> _connectInApp() async {
    await _save();
    if (spotifyService.credentials.clientId.isEmpty) {
      setState(() => _statusMessage = 'Enter a Client ID first');
      return;
    }
    setState(() { _connecting = true; _statusMessage = null; });

    const redirectUri = 'http://127.0.0.1:8888/callback';
    final (:authorizeUrl, :codeVerifier, state: _, redirectUri: usedRedirect) =
        spotifyService.buildAuthUrl(redirectUri: redirectUri);

    final completer = Completer<String?>();

    final webview = await WebviewWindow.create(
      configuration: const CreateConfiguration(title: 'Connect Spotify'),
    );

    webview.addOnUrlRequestCallback((url) {
      if (url.startsWith('http://127.0.0.1:8888/callback')) {
        final code = Uri.parse(url).queryParameters['code'];
        if (!completer.isCompleted) completer.complete(code);
        webview.close();
      }
    });

    webview.onClose.then((_) {
      if (!completer.isCompleted) completer.complete(null);
    });

    webview.launch(authorizeUrl);

    final code = await completer.future;

    if (!mounted) return;
    if (code == null) {
      setState(() { _connecting = false; _statusMessage = 'Login cancelled'; });
      return;
    }

    final result = await spotifyService.handleAuthCode(
      code: code,
      codeVerifier: codeVerifier,
      redirectUri: usedRedirect,
    );
    if (!mounted) return;
    result.when(
      success: (_) => setState(() { _connecting = false; _statusMessage = null; }),
      failure: (e) => setState(() { _connecting = false; _statusMessage = e.message; }),
    );
  }

  Future<void> _saveManual() async {
    final rt = _refreshTokenCtrl.text.trim();
    if (rt.isEmpty) {
      setState(() => _statusMessage = 'Enter a refresh token');
      return;
    }
    await spotifyService.saveRefreshToken(rt);
    _refreshTokenCtrl.clear();
    if (mounted) setState(() { _showManual = false; _statusMessage = null; });
  }

  Future<void> _copyRefreshToken() async {
    final token = spotifyService.credentials.refreshToken;
    if (token == null) return;
    await Clipboard.setData(ClipboardData(text: token));
    setState(() => _tokenCopied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _tokenCopied = false);
  }

  Future<void> _disconnect() async {
    await spotifyService.clearTokens();
    if (mounted) setState(() {});
  }

  String _formatExpiry(DateTime? dt) {
    if (dt == null) return '';
    final diff = dt.difference(DateTime.now());
    if (diff.isNegative) return 'expired';
    if (diff.inHours > 0) return 'in ${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
    return 'in ${diff.inMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final creds = spotifyService.credentials;
    final connected = creds.hasValidToken || creds.canRefresh;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: textHi, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Spotify',
          style: TextStyle(
            color: textHi,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Card(
              label: 'CLIENT ID',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _clientIdCtrl,
                    style: const TextStyle(
                        color: textHi,
                        fontSize: 15,
                        fontWeight: FontWeight.w400),
                    decoration: const InputDecoration(
                      hintText: 'Paste your Spotify Client ID',
                      hintStyle: TextStyle(color: textLo, fontSize: 15),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Register at developer.spotify.com\nSet redirect URI: http://127.0.0.1:8888/callback',
                    style: TextStyle(
                        color: textLo,
                        fontSize: 11,
                        height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: _save,
                      child: const Text(
                        'SAVE',
                        style: TextStyle(
                          color: accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _Card(
              label: 'CONNECTION',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            connected ? 'Connected' : 'Not connected',
                            style: TextStyle(
                              color: connected ? textHi : textLo,
                              fontSize: 18,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          if (connected && creds.expiresAt != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Token expires ${_formatExpiry(creds.expiresAt)}',
                              style: const TextStyle(color: textLo, fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                      const Spacer(),
                      if (connected)
                        GestureDetector(
                          onTap: _disconnect,
                          child: const Text(
                            'DISCONNECT',
                            style: TextStyle(
                              color: accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (connected && creds.refreshToken != null) ...[
                    const SizedBox(height: 14),
                    const Divider(height: 1, thickness: 1, color: border),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Copy refresh token to set up another device (e.g. Pi under Cage).',
                            style: TextStyle(color: textLo, fontSize: 11, height: 1.5),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _copyRefreshToken,
                          child: Text(
                            _tokenCopied ? 'COPIED!' : 'COPY TOKEN',
                            style: TextStyle(
                              color: _tokenCopied ? Colors.green : accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            _Card(
              label: 'PASTE REFRESH TOKEN',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _showManual = !_showManual),
                    child: Row(children: [
                      const Expanded(
                        child: Text(
                          'Authenticate on another machine, copy the refresh token there, paste it here.',
                          style: TextStyle(color: textLo, fontSize: 11, height: 1.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _showManual ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        color: textLo, size: 18,
                      ),
                    ]),
                  ),
                  if (_showManual) ...[
                    const SizedBox(height: 14),
                    _TokenField(
                      controller: _refreshTokenCtrl,
                      hint: 'Refresh Token',
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: _saveManual,
                        child: const Text(
                          'SAVE',
                          style: TextStyle(
                            color: accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_tokenImported) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                    SizedBox(width: 8),
                    Text('Refresh token imported from drop file',
                        style: TextStyle(color: Colors.green, fontSize: 12)),
                  ],
                ),
              ),
            ],
            if (_statusMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _statusMessage!,
                style: const TextStyle(
                    color: Color(0xFFE53935), fontSize: 12),
              ),
            ],
            if (!connected) ...[
              const SizedBox(height: 20),
              if (_connecting)
                const Center(
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(color: accent, strokeWidth: 2),
                  ),
                )
              else
                _ConnectButton(
                  label: 'CONNECT',
                  icon: Icons.login_rounded,
                  onTap: _connectInApp,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConnectButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ConnectButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TokenField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const _TokenField({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: TextField(
        controller: controller,
        obscureText: true,
        style: const TextStyle(
            color: textHi, fontSize: 13, fontFamily: 'monospace'),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: textLo, fontSize: 13),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String label;
  final Widget child;

  const _Card({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: textLo,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
