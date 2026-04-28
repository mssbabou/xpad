import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xpad/app/app_state.dart';
import 'package:xpad/app/theme.dart';
import 'package:xpad/services/spotify/spotify_oauth_server.dart';
import 'package:xpad/services/spotify/spotify_service.dart';

class SpotifySettingsPage extends StatefulWidget {
  const SpotifySettingsPage({super.key});

  @override
  State<SpotifySettingsPage> createState() => _SpotifySettingsPageState();
}

class _SpotifySettingsPageState extends State<SpotifySettingsPage> {
  late final TextEditingController _clientIdCtrl;
  late final TextEditingController _accessTokenCtrl;
  late final TextEditingController _refreshTokenCtrl;
  bool _connecting = false;
  bool _showManual = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _clientIdCtrl =
        TextEditingController(text: spotifyService.credentials.clientId);
    _accessTokenCtrl = TextEditingController();
    _refreshTokenCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _clientIdCtrl.dispose();
    _accessTokenCtrl.dispose();
    _refreshTokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final id = _clientIdCtrl.text.trim();
    await spotifyService.saveClientId(id);
    if (mounted) setState(() {});
  }

  Future<void> _connect() async {
    await _save();
    if (spotifyService.credentials.clientId.isEmpty) {
      setState(() => _statusMessage = 'Enter a Client ID first');
      return;
    }
    setState(() { _connecting = true; _statusMessage = null; });
    await _runOAuth(useNetwork: false);
  }

  Future<void> _connectQr() async {
    await _save();
    if (spotifyService.credentials.clientId.isEmpty) {
      setState(() => _statusMessage = 'Enter a Client ID first');
      return;
    }
    setState(() { _connecting = true; _statusMessage = null; });
    await _runOAuth(useNetwork: true);
  }

  Future<void> _runOAuth({required bool useNetwork}) async {
    final localIp = useNetwork ? await SpotifyService.getLocalIp() : '127.0.0.1';
    final redirectUri = 'http://$localIp:8888/callback';
    final (:authorizeUrl, :codeVerifier, state: _, redirectUri: usedRedirect) =
        spotifyService.buildAuthUrl(redirectUri: redirectUri);

    final server = SpotifyOAuthServer();

    if (useNetwork) {
      // Show QR dialog — user scans with phone
      if (!mounted) return;
      _showQrDialog(
        authorizeUrl: authorizeUrl,
        redirectUri: usedRedirect,
        localIp: localIp,
      );
    } else {
      // Open browser locally
      try {
        final launched = await launchUrl(
          Uri.parse(authorizeUrl),
          mode: LaunchMode.externalApplication,
        );
        if (!launched) {
          setState(() { _connecting = false; _statusMessage = 'Could not open browser'; });
          server.cancel();
          return;
        }
      } catch (_) {
        setState(() { _connecting = false; _statusMessage = 'Could not open browser — try QR code instead'; });
        server.cancel();
        return;
      }
    }

    try {
      final code = await server.waitForCode().timeout(const Duration(minutes: 5));
      final result = await spotifyService.handleAuthCode(
        code: code,
        codeVerifier: codeVerifier,
        redirectUri: usedRedirect,
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst || r.settings.name == '/spotify-settings');
      result.when(
        success: (_) => setState(() { _connecting = false; _statusMessage = null; }),
        failure: (e) => setState(() { _connecting = false; _statusMessage = e.message; }),
      );
    } on TimeoutException {
      server.cancel();
      if (mounted) {
        Navigator.of(context, rootNavigator: true).maybePop();
        setState(() { _connecting = false; _statusMessage = 'Authentication timed out'; });
      }
    } catch (e) {
      server.cancel();
      if (mounted) {
        Navigator.of(context, rootNavigator: true).maybePop();
        setState(() { _connecting = false; _statusMessage = 'Authentication failed: $e'; });
      }
    }
  }

  void _showQrDialog({
    required String authorizeUrl,
    required String redirectUri,
    required String localIp,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _QrDialog(
        authorizeUrl: authorizeUrl,
        redirectUri: redirectUri,
        localIp: localIp,
        onCancel: () {
          setState(() { _connecting = false; _statusMessage = null; });
        },
      ),
    );
  }

  Future<void> _saveManual() async {
    final at = _accessTokenCtrl.text.trim();
    final rt = _refreshTokenCtrl.text.trim();
    if (at.isEmpty || rt.isEmpty) {
      setState(() => _statusMessage = 'Enter both access token and refresh token');
      return;
    }
    await spotifyService.saveTokensManually(accessToken: at, refreshToken: rt);
    _accessTokenCtrl.clear();
    _refreshTokenCtrl.clear();
    if (mounted) setState(() { _showManual = false; _statusMessage = null; });
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
              child: Row(
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
                          style: const TextStyle(
                              color: textLo, fontSize: 11),
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
            ),
            const SizedBox(height: 14),
            _Card(
              label: 'MANUAL TOKEN ENTRY',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _showManual = !_showManual),
                    child: Row(children: [
                      const Expanded(
                        child: Text(
                          'For kiosk / headless devices — paste tokens obtained on another machine.',
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
                      controller: _accessTokenCtrl,
                      hint: 'Access Token',
                    ),
                    const SizedBox(height: 10),
                    _TokenField(
                      controller: _refreshTokenCtrl,
                      hint: 'Refresh Token',
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Get tokens at developer.spotify.com/console or by running the OAuth flow on another device.',
                      style: TextStyle(color: textLo, fontSize: 10, height: 1.5),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: _saveManual,
                        child: const Text(
                          'SAVE TOKENS',
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
                Row(children: [
                  Expanded(
                    child: _ConnectButton(
                      label: 'CONNECT',
                      icon: Icons.open_in_browser_rounded,
                      onTap: _connect,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ConnectButton(
                      label: 'QR CODE',
                      icon: Icons.qr_code_rounded,
                      onTap: _connectQr,
                      outlined: true,
                    ),
                  ),
                ]),
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
  final bool outlined;

  const _ConnectButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : accent,
          borderRadius: BorderRadius.circular(14),
          border: outlined ? Border.all(color: accent) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: outlined ? accent : Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: outlined ? accent : Colors.white,
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

class _QrDialog extends StatelessWidget {
  final String authorizeUrl;
  final String redirectUri;
  final String localIp;
  final VoidCallback onCancel;

  const _QrDialog({
    required this.authorizeUrl,
    required this.redirectUri,
    required this.localIp,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Scan to Connect',
              style: TextStyle(
                color: textHi,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Scan with your phone then log in to Spotify.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: textLo, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: authorizeUrl,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('REDIRECT URI — add this to your Spotify app',
                      style: TextStyle(
                          color: textLo,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4)),
                  const SizedBox(height: 4),
                  Text(
                    redirectUri,
                    style: const TextStyle(
                        color: textHi,
                        fontSize: 12,
                        fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Waiting for login…',
              style: TextStyle(color: textLo, fontSize: 12),
            ),
            const SizedBox(height: 4),
            const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(color: accent, strokeWidth: 2),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onCancel();
              },
              child: const Text('Cancel',
                  style: TextStyle(color: textLo, fontSize: 13)),
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
