import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xpad/core/result.dart';
import 'package:xpad/services/spotify/spotify_models.dart';

class TokenResponse {
  final String accessToken;
  final String? refreshToken;
  final int expiresIn;

  const TokenResponse({
    required this.accessToken,
    this.refreshToken,
    required this.expiresIn,
  });
}

class SpotifyApi {
  final http.Client _client;

  static const _baseUrl = 'https://api.spotify.com/v1';
  static const _accountsUrl = 'https://accounts.spotify.com';
  static const _timeout = Duration(seconds: 8);

  SpotifyApi({http.Client? client}) : _client = client ?? http.Client();


  Future<Result<SpotifyPlaybackState?>> getPlaybackState(String accessToken) async {
    final uri = Uri.parse('$_baseUrl/me/player');
    try {
      final response = await _client
          .get(uri, headers: _headers(accessToken))
          .timeout(_timeout);

      if (response.statusCode == 204) return const Success(null);
      if (response.statusCode == 401) {
        return Failure(AppError(
          kind: ErrorKind.auth,
          message: 'Spotify token expired',
          debugDetail: 'HTTP 401',
        ));
      }
      if (response.statusCode != 200) {
        return Failure(AppError(
          kind: ErrorKind.server,
          message: 'Could not fetch playback state',
          debugDetail: 'HTTP ${response.statusCode}',
        ));
      }

      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        // Spotify sometimes returns 200 with no item (podcast episode or local file with no metadata)
        if (json['item'] == null) return const Success(null);
        return Success(SpotifyPlaybackState.fromJson(json));
      } catch (e) {
        return Failure(AppError(
          kind: ErrorKind.parsing,
          message: 'Could not read playback data',
          debugDetail: e.toString(),
          originalError: e,
        ));
      }
    } on http.ClientException catch (e) {
      return Failure(AppError(
        kind: ErrorKind.network,
        message: 'Could not reach Spotify',
        debugDetail: e.message,
        originalError: e,
      ));
    } on TimeoutException catch (e) {
      return Failure(AppError(
        kind: ErrorKind.network,
        message: 'Spotify request timed out',
        originalError: e,
      ));
    } catch (e) {
      return Failure(AppError(
        kind: ErrorKind.unknown,
        message: 'Error fetching Spotify data',
        debugDetail: e.toString(),
        originalError: e,
      ));
    }
  }

  Map<String, String> _headers(String accessToken, {bool hasBody = false}) => {
        'Authorization': 'Bearer $accessToken',
        if (hasBody) 'Content-Type': 'application/json',
      };

  Future<Result<void>> _sendControl(String accessToken, String method, String path,
      {String? body}) async {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = _headers(accessToken, hasBody: body != null);
    try {
      final http.Response response;
      if (method == 'POST') {
        response = await _client
            .post(uri, headers: headers, body: body)
            .timeout(_timeout);
      } else {
        response = await _client
            .put(uri, headers: headers, body: body)
            .timeout(_timeout);
      }

      if (response.statusCode == 401) {
        return Failure(AppError(
          kind: ErrorKind.auth,
          message: 'Spotify token expired',
          debugDetail: 'HTTP 401',
        ));
      }
      if (response.statusCode >= 400) {
        return Failure(AppError(
          kind: ErrorKind.server,
          message: 'Spotify control failed',
          debugDetail: 'HTTP ${response.statusCode}: ${response.body}',
        ));
      }
      return const Success(null);
    } on http.ClientException catch (e) {
      return Failure(AppError(
        kind: ErrorKind.network,
        message: 'Could not reach Spotify',
        debugDetail: e.message,
        originalError: e,
      ));
    } on TimeoutException catch (e) {
      return Failure(AppError(
        kind: ErrorKind.network,
        message: 'Spotify request timed out',
        originalError: e,
      ));
    } catch (e) {
      return Failure(AppError(
        kind: ErrorKind.unknown,
        message: 'Spotify error',
        debugDetail: e.toString(),
        originalError: e,
      ));
    }
  }

  Future<Result<void>> play(String accessToken) =>
      _sendControl(accessToken, 'PUT', '/me/player/play');

  Future<Result<void>> pause(String accessToken) =>
      _sendControl(accessToken, 'PUT', '/me/player/pause');

  Future<Result<void>> skipNext(String accessToken) =>
      _sendControl(accessToken, 'POST', '/me/player/next');

  Future<Result<void>> skipPrevious(String accessToken) =>
      _sendControl(accessToken, 'POST', '/me/player/previous');

  Future<Result<void>> seek(String accessToken, int positionMs) =>
      _sendControl(
        accessToken,
        'PUT',
        '/me/player/seek?position_ms=$positionMs',
      );

  Future<Result<void>> setShuffle(String accessToken, bool state) =>
      _sendControl(
        accessToken,
        'PUT',
        '/me/player/shuffle?state=$state',
      );

  Future<Result<void>> setRepeat(String accessToken, RepeatState state) =>
      _sendControl(
        accessToken,
        'PUT',
        '/me/player/repeat?state=${state.apiValue}',
      );

  Future<Result<void>> setVolume(String accessToken, int percent) =>
      _sendControl(
        accessToken,
        'PUT',
        '/me/player/volume?volume_percent=${percent.clamp(0, 100)}',
      );

  Future<Result<TokenResponse>> exchangeCode({
    required String code,
    required String codeVerifier,
    required String clientId,
    required String redirectUri,
  }) async {
    final uri = Uri.parse('$_accountsUrl/api/token');
    try {
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirectUri,
          'client_id': clientId,
          'code_verifier': codeVerifier,
        },
      ).timeout(_timeout);

      return _parseTokenResponse(response);
    } on http.ClientException catch (e) {
      return Failure(AppError(
        kind: ErrorKind.network,
        message: 'Could not reach Spotify',
        debugDetail: e.message,
        originalError: e,
      ));
    } on TimeoutException catch (e) {
      return Failure(AppError(
        kind: ErrorKind.network,
        message: 'Spotify request timed out',
        originalError: e,
      ));
    } catch (e) {
      return Failure(AppError(
        kind: ErrorKind.unknown,
        message: 'Authentication error',
        debugDetail: e.toString(),
        originalError: e,
      ));
    }
  }

  Future<Result<TokenResponse>> refreshToken({
    required String refreshToken,
    required String clientId,
  }) async {
    final uri = Uri.parse('$_accountsUrl/api/token');
    try {
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'client_id': clientId,
        },
      ).timeout(_timeout);

      return _parseTokenResponse(response);
    } on http.ClientException catch (e) {
      return Failure(AppError(
        kind: ErrorKind.network,
        message: 'Could not reach Spotify',
        debugDetail: e.message,
        originalError: e,
      ));
    } on TimeoutException catch (e) {
      return Failure(AppError(
        kind: ErrorKind.network,
        message: 'Spotify request timed out',
        originalError: e,
      ));
    } catch (e) {
      return Failure(AppError(
        kind: ErrorKind.unknown,
        message: 'Token refresh error',
        debugDetail: e.toString(),
        originalError: e,
      ));
    }
  }

  Result<TokenResponse> _parseTokenResponse(http.Response response) {
    if (response.statusCode != 200) {
      return Failure(AppError(
        kind: ErrorKind.auth,
        message: 'Authentication failed',
        debugDetail: 'HTTP ${response.statusCode}: ${response.body}',
      ));
    }
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Success(TokenResponse(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String?,
        expiresIn: json['expires_in'] as int,
      ));
    } catch (e) {
      return Failure(AppError(
        kind: ErrorKind.parsing,
        message: 'Could not read token response',
        debugDetail: e.toString(),
        originalError: e,
      ));
    }
  }

  void dispose() => _client.close();
}
