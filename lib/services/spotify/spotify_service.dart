import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xpad/core/result.dart';
import 'package:xpad/services/spotify/spotify_api.dart';
import 'package:xpad/services/spotify/spotify_models.dart';
import 'package:xpad/services/spotify/spotify_oauth_server.dart';

export 'package:xpad/services/spotify/spotify_models.dart';

class SpotifyService {
  final SpotifyApi _api;

  SpotifyCredentials _credentials = SpotifyCredentials.empty();
  SpotifyPlaybackState? _lastState;

  // Refresh race protection
  Future<Result<String>>? _pendingRefresh;

  static const _keyClientId = 'spotify_client_id';
  static const _keyAccessToken = 'spotify_access_token';
  static const _keyRefreshToken = 'spotify_refresh_token';
  static const _keyExpiresAt = 'spotify_expires_at';

  static const _localhostRedirectUri = 'http://127.0.0.1:8888/callback';
  static const _scopes = 'user-read-playback-state user-modify-playback-state';

  SpotifyService({SpotifyApi? api}) : _api = api ?? SpotifyApi();

  SpotifyCredentials get credentials => _credentials;
  SpotifyPlaybackState? get lastState => _lastState;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final expiresAtMs = prefs.getInt(_keyExpiresAt);
    _credentials = SpotifyCredentials(
      clientId: prefs.getString(_keyClientId) ?? '',
      accessToken: prefs.getString(_keyAccessToken),
      refreshToken: prefs.getString(_keyRefreshToken),
      expiresAt: expiresAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(expiresAtMs)
          : null,
    );
  }

  Future<void> saveCredentials(SpotifyCredentials creds) async {
    _credentials = creds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyClientId, creds.clientId);
    if (creds.accessToken != null) {
      await prefs.setString(_keyAccessToken, creds.accessToken!);
    } else {
      await prefs.remove(_keyAccessToken);
    }
    if (creds.refreshToken != null) {
      await prefs.setString(_keyRefreshToken, creds.refreshToken!);
    } else {
      await prefs.remove(_keyRefreshToken);
    }
    if (creds.expiresAt != null) {
      await prefs.setInt(
          _keyExpiresAt, creds.expiresAt!.millisecondsSinceEpoch);
    } else {
      await prefs.remove(_keyExpiresAt);
    }
  }

  Future<void> saveClientId(String clientId) async {
    await saveCredentials(_credentials.copyWith(clientId: clientId));
  }

  Future<void> saveTokensManually({
    required String accessToken,
    required String refreshToken,
  }) async {
    await saveCredentials(_credentials.copyWith(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    ));
  }

  Future<void> clearTokens() async {
    await saveCredentials(SpotifyCredentials(clientId: _credentials.clientId));
    _lastState = null;
  }

  static Future<String> getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      final addr = interfaces
          .expand((i) => i.addresses)
          .where((a) => !a.isLoopback)
          .firstOrNull;
      return addr?.address ?? '127.0.0.1';
    } catch (_) {
      return '127.0.0.1';
    }
  }

  ({String authorizeUrl, String codeVerifier, String state, String redirectUri})
      buildAuthUrl({String? redirectUri}) {
    final redirect = redirectUri ?? _localhostRedirectUri;
    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(codeVerifier);
    final state = _generateState();

    final uri = Uri.parse('https://accounts.spotify.com/authorize').replace(
      queryParameters: {
        'client_id': _credentials.clientId,
        'response_type': 'code',
        'redirect_uri': redirect,
        'scope': _scopes,
        'code_challenge_method': 'S256',
        'code_challenge': codeChallenge,
        'state': state,
      },
    );

    return (
      authorizeUrl: uri.toString(),
      codeVerifier: codeVerifier,
      state: state,
      redirectUri: redirect,
    );
  }

  Future<Result<void>> handleAuthCode({
    required String code,
    required String codeVerifier,
    required String redirectUri,
  }) async {
    final result = await _api.exchangeCode(
      code: code,
      codeVerifier: codeVerifier,
      clientId: _credentials.clientId,
      redirectUri: redirectUri,
    );

    return result.when(
      success: (token) async {
        final expiresAt =
            DateTime.now().add(Duration(seconds: token.expiresIn));
        await saveCredentials(_credentials.copyWith(
          accessToken: token.accessToken,
          refreshToken: token.refreshToken ?? _credentials.refreshToken,
          expiresAt: expiresAt,
        ));
        return const Success(null);
      },
      failure: (e) => Failure<void>(e),
    );
  }

  Future<Result<String>> _getValidToken() async {
    if (_credentials.hasValidToken) {
      return Success(_credentials.accessToken!);
    }

    if (_pendingRefresh != null) return _pendingRefresh!;

    if (!_credentials.canRefresh) {
      return Failure(AppError(
        kind: ErrorKind.auth,
        message: 'Not authenticated with Spotify',
      ));
    }

    _pendingRefresh = _doRefresh();
    final result = await _pendingRefresh!;
    _pendingRefresh = null;
    return result;
  }

  Future<Result<String>> _doRefresh() async {
    final result = await _api.refreshToken(
      refreshToken: _credentials.refreshToken!,
      clientId: _credentials.clientId,
    );

    return result.when(
      success: (token) async {
        final expiresAt =
            DateTime.now().add(Duration(seconds: token.expiresIn));
        await saveCredentials(_credentials.copyWith(
          accessToken: token.accessToken,
          refreshToken: token.refreshToken ?? _credentials.refreshToken,
          expiresAt: expiresAt,
        ));
        return Success(token.accessToken);
      },
      failure: (e) => Failure<String>(e),
    );
  }

  Stream<SpotifyPlaybackState?> playbackStream({
    Duration interval = const Duration(seconds: 3),
  }) async* {
    yield _lastState;
    yield* Stream.periodic(interval).asyncMap((_) => _fetchState());
  }

  Future<SpotifyPlaybackState?> _fetchState() async {
    final tokenResult = await _getValidToken();
    if (tokenResult case Failure()) return _lastState;

    final result =
        await _api.getPlaybackState((tokenResult as Success<String>).data);
    if (result case Success(:final data)) {
      if (data != null) {
        _lastState = data;
        return data;
      }
      // 204 — nothing active. Return last known state as paused so UI stays populated.
      if (_lastState != null) {
        return SpotifyPlaybackState(
          track: _lastState!.track,
          isPlaying: false,
          progressMs: _lastState!.progressMs,
          shuffleState: _lastState!.shuffleState,
          repeatState: _lastState!.repeatState,
          deviceName: null,
          deviceVolumePercent: _lastState!.deviceVolumePercent,
          fetchedAt: DateTime.now(),
        );
      }
      return null;
    }
    return _lastState;
  }

  Future<Result<void>> _control(
      Future<Result<void>> Function(String token) action) async {
    final tokenResult = await _getValidToken();
    return tokenResult.when(
      success: (token) => action(token),
      failure: (e) => Failure(e),
    );
  }

  Future<Result<void>> play() => _control(_api.play);
  Future<Result<void>> pause() => _control(_api.pause);
  Future<Result<void>> skipNext() => _control(_api.skipNext);
  Future<Result<void>> skipPrevious() => _control(_api.skipPrevious);

  Future<Result<void>> seek(int positionMs) =>
      _control((t) => _api.seek(t, positionMs));

  Future<Result<void>> toggleShuffle() async {
    final current = _lastState?.shuffleState ?? false;
    return _control((t) => _api.setShuffle(t, !current));
  }

  Future<Result<void>> setVolume(int percent) =>
      _control((t) => _api.setVolume(t, percent));

  Future<Result<void>> cycleRepeat() async {
    final current = _lastState?.repeatState ?? RepeatState.off;
    final next = switch (current) {
      RepeatState.off => RepeatState.context,
      RepeatState.context => RepeatState.track,
      RepeatState.track => RepeatState.off,
    };
    return _control((t) => _api.setRepeat(t, next));
  }

  Future<String> waitForOAuthCode() {
    final server = SpotifyOAuthServer();
    return server.waitForCode();
  }

  String _generateCodeVerifier() {
    final rng = Random.secure();
    final bytes = List<int>.generate(64, (_) => rng.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  String _generateState() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  void dispose() => _api.dispose();
}
