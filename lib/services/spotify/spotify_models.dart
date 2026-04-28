class SpotifyTrack {
  final String id;
  final String name;
  final List<String> artists;
  final String albumName;
  final String? albumImageUrl;
  final int durationMs;
  final DateTime fetchedAt;

  const SpotifyTrack({
    required this.id,
    required this.name,
    required this.artists,
    required this.albumName,
    this.albumImageUrl,
    required this.durationMs,
    required this.fetchedAt,
  });

  factory SpotifyTrack.fromJson(Map<String, dynamic> json) {
    final album = json['album'] as Map<String, dynamic>? ?? {};
    final images = (album['images'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final artistList = (json['artists'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return SpotifyTrack(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown Track',
      artists: artistList.map((a) => a['name'] as String? ?? '').toList(),
      albumName: album['name'] as String? ?? '',
      albumImageUrl: images.isNotEmpty ? images.first['url'] as String? : null,
      durationMs: json['duration_ms'] as int? ?? 0,
      fetchedAt: DateTime.now(),
    );
  }

  String get artistsString => artists.join(', ');
}

enum RepeatState {
  off,
  track,
  context;

  static RepeatState fromString(String s) => switch (s) {
        'track' => track,
        'context' => context,
        _ => off,
      };

  String get apiValue => switch (this) {
        off => 'off',
        track => 'track',
        context => 'context',
      };
}

class SpotifyPlaybackState {
  final SpotifyTrack track;
  final bool isPlaying;
  final int progressMs;
  final bool shuffleState;
  final RepeatState repeatState;
  final String? deviceName;
  final int? deviceVolumePercent;
  final DateTime fetchedAt;

  const SpotifyPlaybackState({
    required this.track,
    required this.isPlaying,
    required this.progressMs,
    required this.shuffleState,
    required this.repeatState,
    this.deviceName,
    this.deviceVolumePercent,
    required this.fetchedAt,
  });

  factory SpotifyPlaybackState.fromJson(Map<String, dynamic> json) {
    final item = json['item'] as Map<String, dynamic>? ?? {};
    final device = json['device'] as Map<String, dynamic>?;

    return SpotifyPlaybackState(
      track: SpotifyTrack.fromJson(item),
      isPlaying: json['is_playing'] as bool? ?? false,
      progressMs: json['progress_ms'] as int? ?? 0,
      shuffleState: json['shuffle_state'] as bool? ?? false,
      repeatState: RepeatState.fromString(json['repeat_state'] as String? ?? 'off'),
      deviceName: device?['name'] as String?,
      deviceVolumePercent: device?['volume_percent'] as int?,
      fetchedAt: DateTime.now(),
    );
  }
}

class SpotifyCredentials {
  final String clientId;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;

  const SpotifyCredentials({
    required this.clientId,
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
  });

  factory SpotifyCredentials.empty() => const SpotifyCredentials(clientId: '');

  bool get isExpired =>
      expiresAt == null ||
      DateTime.now().isAfter(expiresAt!.subtract(const Duration(seconds: 30)));

  bool get hasValidToken => accessToken != null && !isExpired;

  bool get canRefresh => refreshToken != null && clientId.isNotEmpty;

  SpotifyCredentials copyWith({
    String? clientId,
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    bool clearAccessToken = false,
    bool clearRefreshToken = false,
  }) {
    return SpotifyCredentials(
      clientId: clientId ?? this.clientId,
      accessToken: clearAccessToken ? null : (accessToken ?? this.accessToken),
      refreshToken: clearRefreshToken ? null : (refreshToken ?? this.refreshToken),
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}
