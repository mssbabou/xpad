import 'package:flutter/material.dart';
import 'package:xpad/app/app_state.dart';
import 'package:xpad/app/theme.dart';
import 'package:xpad/pages/settings/octoprint_settings_page.dart';
import 'package:xpad/services/octoprint/octoprint_service.dart';

class OctoPrintPage extends StatefulWidget {
  const OctoPrintPage({super.key});

  @override
  State<OctoPrintPage> createState() => _OctoPrintPageState();
}

class _OctoPrintPageState extends State<OctoPrintPage> {
  List<OctoPrintFile>? _files;
  String? _filesError;
  bool _loadingFiles = false;
  bool _actionPending = false;
  Stream<Result<OctoPrintStatus>>? _statusStream;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  void _boot() {
    if (!octoprintService.isConfigured) return;
    _statusStream = octoprintService.statusStream();
    _fetchFiles();
  }

  Future<void> _fetchFiles() async {
    if (!octoprintService.isConfigured) return;
    setState(() { _loadingFiles = true; _filesError = null; });
    final result = await octoprintService.getFiles();
    if (!mounted) return;
    result.when(
      success: (files) => setState(() { _files = files; _loadingFiles = false; }),
      failure: (e) => setState(() { _filesError = e.message; _loadingFiles = false; }),
    );
  }

  Future<void> _action(Future<Result<void>> Function() fn) async {
    setState(() => _actionPending = true);
    final result = await fn();
    if (!mounted) return;
    setState(() => _actionPending = false);
    if (result case Failure(:final error)) _showError(error.message);
  }

  Future<void> _confirmPrint(OctoPrintFile file) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Print this file?',
            style: TextStyle(color: textHi, fontSize: 17, fontWeight: FontWeight.w600)),
        content: Text(file.name, style: const TextStyle(color: textLo, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: textLo)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Print',
                style: TextStyle(color: accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) _action(() => octoprintService.printFile(file.path));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFFE53935),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _goToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OctoPrintSettingsPage()),
    ).then((_) {
      if (octoprintService.isConfigured) {
        setState(() => _statusStream = octoprintService.statusStream());
        _fetchFiles();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!octoprintService.isConfigured) {
      return _NotConfigured(onSettings: _goToSettings);
    }

    return Scaffold(
      backgroundColor: bg,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: StreamBuilder<Result<OctoPrintStatus>>(
          stream: _statusStream,
          builder: (context, snapshot) {
            final status = snapshot.data?.when(
              success: (s) => s,
              failure: (_) => null,
            );
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Left half: status card + file list ─────────────────
                Expanded(
                  child: _LeftColumn(
                    status: status,
                    files: _files,
                    filesError: _filesError,
                    loadingFiles: _loadingFiles,
                    actionPending: _actionPending,
                    onRefresh: _fetchFiles,
                    onPrint: _confirmPrint,
                    onPause: () => _action(octoprintService.pause),
                    onResume: () => _action(octoprintService.resume),
                    onCancel: () => _action(octoprintService.cancel),
                  ),
                ),
                const SizedBox(width: 16),
                // ── Right half: temperatures + preheat ─────────────────
                Expanded(
                  child: _RightColumn(
                    hotend: status?.hotend,
                    bed: status?.bed,
                    onPreheat: (p) => _action(
                        () => octoprintService.preheat(p.hotend, p.bed)),
                    onCooldown: () => _action(octoprintService.cooldown),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Left column ────────────────────────────────────────────────────────────────

class _LeftColumn extends StatelessWidget {
  final OctoPrintStatus? status;
  final List<OctoPrintFile>? files;
  final String? filesError;
  final bool loadingFiles;
  final bool actionPending;
  final Future<void> Function() onRefresh;
  final void Function(OctoPrintFile) onPrint;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  const _LeftColumn({
    required this.status,
    required this.files,
    required this.filesError,
    required this.loadingFiles,
    required this.actionPending,
    required this.onRefresh,
    required this.onPrint,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status card
        _StatusCard(
          status: status,
          actionPending: actionPending,
          onPause: onPause,
          onResume: onResume,
          onCancel: onCancel,
        ),
        const SizedBox(height: 16),
        // Files header
        Row(
          children: [
            const Text('FILES',
                style: TextStyle(
                    color: textLo,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6)),
            const Spacer(),
            if (loadingFiles)
              const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(color: textLo, strokeWidth: 1.5))
            else
              GestureDetector(
                onTap: onRefresh,
                child: const Icon(Icons.refresh_rounded, color: textLo, size: 18),
              ),
          ],
        ),
        const SizedBox(height: 10),
        // File list
        Expanded(
          child: filesError != null
              ? Center(
                  child: Text(filesError!,
                      style: const TextStyle(color: textLo, fontSize: 13)))
              : files == null
                  ? const Center(
                      child: CircularProgressIndicator(color: accent, strokeWidth: 2))
                  : files!.isEmpty
                      ? const Center(
                          child: Text('No G-code files found',
                              style: TextStyle(color: textLo, fontSize: 13)))
                      : RefreshIndicator(
                          onRefresh: onRefresh,
                          color: accent,
                          child: ListView.builder(
                            itemCount: files!.length,
                            itemBuilder: (context, i) => _FileRow(
                              file: files![i],
                              onTap: () => onPrint(files![i]),
                            ),
                          ),
                        ),
        ),
      ],
    );
  }
}

// ── Status card ────────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final OctoPrintStatus? status;
  final bool actionPending;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  const _StatusCard({
    required this.status,
    required this.actionPending,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final job = status?.job;
    final state = status?.state;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('PRINTER',
                  style: TextStyle(
                      color: textLo,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6)),
              const Spacer(),
              _StatePill(state: state),
            ],
          ),
          const SizedBox(height: 12),
          if (job != null) ...[
            Text(
              job.filename,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: textHi, fontSize: 13, fontWeight: FontWeight.w500, height: 1.35),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: job.completion.clamp(0.0, 100.0) / 100,
                minHeight: 5,
                backgroundColor: border,
                valueColor: const AlwaysStoppedAnimation(accent),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('${job.completion.clamp(0.0, 100.0).toStringAsFixed(1)}%',
                    style: const TextStyle(
                        color: accent, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(width: 10),
                Text('${_fmt(job.printTimeSeconds)} elapsed',
                    style: const TextStyle(color: textLo, fontSize: 11)),
                if (job.printTimeLeftSeconds != null) ...[
                  const Text('  ·  ', style: TextStyle(color: textLo, fontSize: 11)),
                  Text('~${_fmt(job.printTimeLeftSeconds!)} left',
                      style: const TextStyle(color: textLo, fontSize: 11)),
                ],
              ],
            ),
          ] else
            Text(
              _idleLabel(state),
              style: const TextStyle(color: textLo, fontSize: 13),
            ),
          if (status != null && job != null) ...[
            const SizedBox(height: 12),
            _Controls(
              state: state!,
              pending: actionPending,
              onPause: onPause,
              onResume: onResume,
              onCancel: onCancel,
            ),
          ],
        ],
      ),
    );
  }

  static String _idleLabel(PrinterState? s) => switch (s) {
        PrinterState.operational => 'Ready to print',
        PrinterState.offline => 'Printer offline',
        PrinterState.error => 'Printer error',
        null => 'Connecting…',
        _ => 'Idle',
      };

  static String _fmt(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

class _StatePill extends StatelessWidget {
  final PrinterState? state;
  const _StatePill({this.state});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      PrinterState.printing => ('Printing', const Color(0xFF1DB954)),
      PrinterState.pausing => ('Pausing', const Color(0xFFFF9800)),
      PrinterState.paused => ('Paused', const Color(0xFFFF9800)),
      PrinterState.cancelling => ('Cancelling', const Color(0xFFE53935)),
      PrinterState.error => ('Error', const Color(0xFFE53935)),
      PrinterState.offline => ('Offline', textLo),
      PrinterState.operational => ('Ready', const Color(0xFF1DB954)),
      _ => ('—', textLo),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
    );
  }
}

class _Controls extends StatelessWidget {
  final PrinterState state;
  final bool pending;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  const _Controls({
    required this.state,
    required this.pending,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final transitioning =
        state == PrinterState.pausing || state == PrinterState.cancelling || pending;

    if (transitioning) {
      return Row(children: [
        const SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(color: accent, strokeWidth: 2)),
        const SizedBox(width: 8),
        Text(
          state == PrinterState.cancelling ? 'Cancelling…' : 'Please wait…',
          style: const TextStyle(color: textLo, fontSize: 12),
        ),
      ]);
    }

    return Row(
      children: [
        if (state == PrinterState.printing)
          _Btn(label: 'PAUSE', onTap: onPause),
        if (state == PrinterState.paused)
          _Btn(label: 'RESUME', color: const Color(0xFF1DB954), onTap: onResume),
        const SizedBox(width: 8),
        _Btn(label: 'CANCEL', color: const Color(0xFFE53935), outlined: true, onTap: onCancel),
      ],
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final Color color;
  final bool outlined;
  final VoidCallback onTap;

  const _Btn({
    required this.label,
    required this.onTap,
    this.color = accent,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : color,
          borderRadius: BorderRadius.circular(10),
          border: outlined ? Border.all(color: color) : null,
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                color: outlined ? color : Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2)),
      ),
    );
  }
}

// ── File row ───────────────────────────────────────────────────────────────────

class _FileRow extends StatelessWidget {
  final OctoPrintFile file;
  final VoidCallback onTap;
  const _FileRow({required this.file, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sub = [
      if (file.sizeBytes != null) _fmtSize(file.sizeBytes!),
      if (file.estimatedPrintTimeSeconds != null)
        '~${_fmtTime(file.estimatedPrintTimeSeconds!)}',
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: border, width: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.description_outlined, color: textLo, size: 15),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(file.name,
                      style: const TextStyle(
                          color: textHi, fontSize: 13, fontWeight: FontWeight.w400, height: 1.3)),
                  if (sub.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(sub, style: const TextStyle(color: textLo, fontSize: 10)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.play_arrow_rounded, color: accent, size: 20),
          ],
        ),
      ),
    );
  }

  static String _fmtSize(int bytes) {
    if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  static String _fmtTime(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

// ── Right column: temperatures + preheat ──────────────────────────────────────

class _RightColumn extends StatelessWidget {
  final OctoPrintTemperature? hotend;
  final OctoPrintTemperature? bed;
  final void Function(PreheatPreset) onPreheat;
  final VoidCallback onCooldown;

  const _RightColumn({
    required this.hotend,
    required this.bed,
    required this.onPreheat,
    required this.onCooldown,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Temperature cards
        const Text('TEMPERATURES',
            style: TextStyle(
                color: textLo,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _TempCard(label: 'HOTEND', temp: hotend)),
            const SizedBox(width: 12),
            Expanded(child: _TempCard(label: 'BED', temp: bed)),
          ],
        ),
        const SizedBox(height: 24),
        // Preheat presets
        const Text('PREHEAT',
            style: TextStyle(
                color: textLo,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6)),
        const SizedBox(height: 10),
        Row(
          children: preheatPresets.map((p) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                  right: p == preheatPresets.last ? 0 : 8),
              child: _PresetBtn(preset: p, onTap: () => onPreheat(p)),
            ),
          )).toList(),
        ),
        const SizedBox(height: 10),
        // Cooldown — full width
        SizedBox(
          width: double.infinity,
          height: 44,
          child: GestureDetector(
            onTap: onCooldown,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Text('COOLDOWN',
                  style: TextStyle(
                      color: textLo,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2)),
            ),
          ),
        ),
      ],
    );
  }
}

class _TempCard extends StatelessWidget {
  final String label;
  final OctoPrintTemperature? temp;
  const _TempCard({required this.label, required this.temp});

  @override
  Widget build(BuildContext context) {
    final actual = temp?.actual ?? 0;
    final target = temp?.target ?? 0;
    final frac = target > 0 ? (actual / target).clamp(0.0, 1.0) : 0.0;
    final heating = target > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: textLo,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${actual.round()}°',
                style: TextStyle(
                    color: heating ? accent : textHi,
                    fontSize: 36,
                    fontWeight: FontWeight.w200,
                    height: 1,
                    letterSpacing: -1),
              ),
              if (heating)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5, left: 4),
                  child: Text(
                    '/ ${target.round()}°',
                    style: const TextStyle(
                        color: textLo, fontSize: 12, fontWeight: FontWeight.w400),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 4,
              backgroundColor: border,
              valueColor: AlwaysStoppedAnimation(heating ? accent : textLo.withValues(alpha: 0.3)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetBtn extends StatelessWidget {
  final PreheatPreset preset;
  final VoidCallback onTap;
  const _PresetBtn({required this.preset, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(preset.label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            Text('${preset.hotend}° / ${preset.bed}°',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7), fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

// ── Not configured ─────────────────────────────────────────────────────────────

class _NotConfigured extends StatelessWidget {
  final VoidCallback onSettings;
  const _NotConfigured({required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.print_outlined, color: textLo, size: 48),
            const SizedBox(height: 16),
            const Text('OctoPrint not configured',
                style: TextStyle(color: textHi, fontSize: 17, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            const Text('Add your server URL and API key in Settings',
                style: TextStyle(color: textLo, fontSize: 13)),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onSettings,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                    color: accent, borderRadius: BorderRadius.circular(14)),
                child: const Text('Open Settings',
                    style: TextStyle(
                        color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
