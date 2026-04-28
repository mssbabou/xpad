import 'dart:async';

import 'package:flutter/material.dart';
import 'package:xpad/app/app_state.dart';
import 'package:xpad/pages/settings/spotify_settings_page.dart';
import 'package:xpad/services/spotify/spotify_models.dart';

// Spotify dark palette — intentionally local, not from app theme
const _bg      = Color(0xFF121212);
const _surface = Color(0xFF1E1E1E);
const _green   = Color(0xFF1DB954);
const _white   = Color(0xFFFFFFFF);
const _gray    = Color(0xFFB3B3B3);
const _dim     = Color(0xFF535353);

class SpotifyPage extends StatefulWidget {
  const SpotifyPage({super.key});

  @override
  State<SpotifyPage> createState() => _SpotifyPageState();
}

class _SpotifyPageState extends State<SpotifyPage> {
  StreamSubscription<SpotifyPlaybackState?>? _sub;
  SpotifyPlaybackState? _state;
  bool _loaded = false;
  int _interpolatedProgressMs = 0;
  Timer? _progressTimer;
  double _volume = 50;
  bool _volumeDragging = false;
  Timer? _volumeDebounce;

  @override
  void initState() {
    super.initState();
    _sub = spotifyService.playbackStream().listen(_onStateUpdate);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _progressTimer?.cancel();
    _volumeDebounce?.cancel();
    super.dispose();
  }

  void _onStateUpdate(SpotifyPlaybackState? state) {
    if (!mounted) return;
    setState(() {
      _state = state;
      _loaded = true;
      _interpolatedProgressMs = state?.progressMs ?? 0;
      if (!_volumeDragging && state?.deviceVolumePercent != null) {
        _volume = state!.deviceVolumePercent!.toDouble();
      }
    });
    _progressTimer?.cancel();
    if (state != null && state.isPlaying) {
      _progressTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (!mounted) return;
        setState(() {
          _interpolatedProgressMs = (_interpolatedProgressMs + 500)
              .clamp(0, _state?.track.durationMs ?? 0);
        });
      });
    }
  }

  String _formatMs(int ms) {
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _seek(double fraction) {
    final durationMs = _state?.track.durationMs ?? 0;
    final positionMs = (fraction * durationMs).round().clamp(0, durationMs);
    setState(() => _interpolatedProgressMs = positionMs);
    spotifyService.seek(positionMs);
  }

  void _onVolumeChanged(double val) {
    setState(() {
      _volume = val;
      _volumeDragging = true;
    });
    // Debounce API calls while dragging — cancel any pending call
    _volumeDebounce?.cancel();
    _volumeDebounce = Timer(const Duration(milliseconds: 150), () {
      spotifyService.setVolume(val.round());
    });
  }

  void _onVolumeChangeEnd(double val) {
    _volumeDebounce?.cancel();
    setState(() => _volumeDragging = false);
    spotifyService.setVolume(val.round());
  }

  @override
  Widget build(BuildContext context) {
    final creds = spotifyService.credentials;

    if (creds.clientId.isEmpty) {
      return _buildPrompt(
        icon: Icons.music_note_rounded,
        title: 'Set up Spotify',
        subtitle: 'Add your Client ID in Settings\nto get started.',
        buttonLabel: 'Open Spotify Settings',
        onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SpotifySettingsPage()))
            .then((_) => setState(() {})),
      );
    }

    if (!creds.hasValidToken && !creds.canRefresh) {
      return _buildPrompt(
        icon: Icons.link_rounded,
        title: 'Connect to Spotify',
        subtitle: 'Authenticate to start\ncontrolling playback.',
        buttonLabel: 'Open Spotify Settings',
        onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SpotifySettingsPage()))
            .then((_) => setState(() {})),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: !_loaded
            ? const Center(
                child: CircularProgressIndicator(color: _green, strokeWidth: 2))
            : _state == null
                ? _buildNothingPlaying()
                : _buildPlayer(_state!),
      ),
    );
  }

  Widget _buildPrompt({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return Scaffold(
      backgroundColor: _bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icon, color: _gray, size: 32),
              ),
              const SizedBox(height: 20),
              Text(title,
                  style: const TextStyle(
                      color: _white, fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: _gray, fontSize: 14, height: 1.6)),
              const SizedBox(height: 28),
              _PressButton(
                onTap: onTap,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  decoration: BoxDecoration(
                    color: _green,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text(buttonLabel,
                      style: const TextStyle(
                          color: _white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNothingPlaying() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.music_off_rounded, color: _gray, size: 32),
          ),
          const SizedBox(height: 20),
          const Text('Nothing playing',
              style: TextStyle(
                  color: _white, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Start playing something on Spotify\nand it will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _gray, fontSize: 14, height: 1.6)),
        ],
      ),
    );
  }

  Widget _buildPlayer(SpotifyPlaybackState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          const Text('NOW PLAYING',
              style: TextStyle(
                  color: _gray,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6)),

          const SizedBox(height: 20),

          // Main content row
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Track info
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.track.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: _white,
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                height: 1.2),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            state.track.artistsString,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: _gray, fontSize: 16),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            state.track.albumName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: _dim, fontSize: 13),
                          ),
                          if (state.deviceName != null) ...[
                            const SizedBox(height: 10),
                            Row(children: [
                              const Icon(Icons.speaker_rounded,
                                  size: 13, color: _green),
                              const SizedBox(width: 5),
                              Text('Playing on ${state.deviceName}',
                                  style: const TextStyle(
                                      color: _gray, fontSize: 12)),
                            ]),
                          ],
                        ],
                      ),

                      // Controls
                      Row(
                        children: [
                          _PressButton(
                            onTap: () => spotifyService.toggleShuffle(),
                            child: Icon(Icons.shuffle_rounded,
                                size: 22,
                                color: state.shuffleState ? _green : _dim),
                          ),
                          const SizedBox(width: 24),
                          _PressButton(
                            onTap: () => spotifyService.skipPrevious(),
                            child: const Icon(Icons.skip_previous_rounded,
                                size: 32, color: _white),
                          ),
                          const SizedBox(width: 20),
                          _PressButton(
                            scale: 0.92,
                            onTap: () => state.isPlaying
                                ? spotifyService.pause()
                                : spotifyService.play(),
                            child: Container(
                              width: 62,
                              height: 62,
                              decoration: BoxDecoration(
                                color: _green,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _green.withValues(alpha: 0.35),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Icon(
                                state.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: _white,
                                size: 34,
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          _PressButton(
                            onTap: () => spotifyService.skipNext(),
                            child: const Icon(Icons.skip_next_rounded,
                                size: 32, color: _white),
                          ),
                          const SizedBox(width: 24),
                          _PressButton(
                            onTap: () => spotifyService.cycleRepeat(),
                            child: Icon(
                              state.repeatState == RepeatState.track
                                  ? Icons.repeat_one_rounded
                                  : Icons.repeat_rounded,
                              size: 22,
                              color: state.repeatState != RepeatState.off
                                  ? _green
                                  : _dim,
                            ),
                          ),
                        ],
                      ),

                      // Progress bar + times
                      Column(
                        children: [
                          _ProgressBar(
                            progressMs: _interpolatedProgressMs,
                            durationMs: state.track.durationMs,
                            onSeek: _seek,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatMs(_interpolatedProgressMs),
                                  style: const TextStyle(
                                      color: _gray, fontSize: 11)),
                              Text(_formatMs(state.track.durationMs),
                                  style: const TextStyle(
                                      color: _gray, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),

                      // Volume slider
                      Row(
                        children: [
                          const Icon(Icons.volume_down_rounded,
                              size: 18, color: _dim),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 4,
                                activeTrackColor: _green,
                                inactiveTrackColor: _dim,
                                thumbColor: _white,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 7),
                                overlayShape: SliderComponentShape.noOverlay,
                              ),
                              child: Slider(
                                value: _volume,
                                min: 0,
                                max: 100,
                                onChanged: _onVolumeChanged,
                                onChangeEnd: _onVolumeChangeEnd,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.volume_up_rounded,
                              size: 18, color: _dim),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 32),

                // Right: album art
                AspectRatio(
                  aspectRatio: 1,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: _AlbumArt(
                      key: ValueKey(
                          state.track.albumImageUrl ?? state.track.albumName),
                      imageUrl: state.track.albumImageUrl,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlbumArt extends StatelessWidget {
  final String? imageUrl;
  const _AlbumArt({super.key, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _green.withValues(alpha: 0.20),
            blurRadius: 40,
            spreadRadius: 4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: imageUrl != null
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) =>
                    const _PlaceholderArt(),
              )
            : const _PlaceholderArt(),
      ),
    );
  }
}

class _PlaceholderArt extends StatelessWidget {
  const _PlaceholderArt();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _surface,
      child: const Center(
          child: Icon(Icons.music_note_rounded, color: _dim, size: 64)),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int progressMs;
  final int durationMs;
  final void Function(double fraction) onSeek;

  const _ProgressBar({
    required this.progressMs,
    required this.durationMs,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final fraction =
        durationMs > 0 ? (progressMs / durationMs).clamp(0.0, 1.0) : 0.0;

    return LayoutBuilder(builder: (context, constraints) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => onSeek(
            (d.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0)),
        onHorizontalDragUpdate: (d) => onSeek(
            (d.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0)),
        child: SizedBox(
          height: 22,
          child: Center(
            child: CustomPaint(
              size: Size(constraints.maxWidth, 5),
              painter: _ProgressPainter(fraction: fraction),
            ),
          ),
        ),
      );
    });
  }
}

class _ProgressPainter extends CustomPainter {
  final double fraction;
  const _ProgressPainter({required this.fraction});

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, r),
        Paint()..color = _dim);
    if (fraction > 0) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(0, 0, size.width * fraction, size.height), r),
          Paint()..color = _green);
    }
  }

  @override
  bool shouldRepaint(_ProgressPainter old) => old.fraction != fraction;
}

class _PressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scale;

  const _PressButton({
    required this.child,
    required this.onTap,
    this.scale = 0.88,
  });

  @override
  State<_PressButton> createState() => _PressButtonState();
}

class _PressButtonState extends State<_PressButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
