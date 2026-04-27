import 'dart:async';
import 'dart:io';

import 'system_models.dart';

class SystemService {
  _CpuTick? _prevTick;
  SystemStats? lastStats;

  Stream<SystemStats> statsStream() async* {
    yield await _read();
    while (true) {
      await Future.delayed(const Duration(seconds: 2));
      yield await _read();
    }
  }

  Future<SystemStats> _read() async {
    final results = await Future.wait([
      _readCpuTemp(),
      _readUptime(),
      _readMeminfo(),
      _readCpuLoad(),
    ]);
    return lastStats = SystemStats(
      cpuTempC: results[0] as double,
      uptime: results[1] as Duration,
      ramUsedMb: (results[2] as (int, int)).$1,
      ramTotalMb: (results[2] as (int, int)).$2,
      cpuLoadFrac: results[3] as double,
    );
  }

  Future<double> _readCpuTemp() async {
    try {
      final raw = await File('/sys/class/thermal/thermal_zone0/temp').readAsString();
      return int.parse(raw.trim()) / 1000.0;
    } on IOException {
      return 0.0;
    }
  }

  Future<Duration> _readUptime() async {
    try {
      final raw = await File('/proc/uptime').readAsString();
      final seconds = double.parse(raw.trim().split(' ').first);
      return Duration(seconds: seconds.toInt());
    } on IOException {
      return Duration.zero;
    }
  }

  Future<(int, int)> _readMeminfo() async {
    try {
      final lines = await File('/proc/meminfo').readAsLines();
      int total = 0, available = 0;
      for (final line in lines) {
        if (line.startsWith('MemTotal:')) {
          total = _parseMemKb(line);
        } else if (line.startsWith('MemAvailable:')) {
          available = _parseMemKb(line);
        }
        if (total > 0 && available > 0) break;
      }
      final usedMb = (total - available) ~/ 1024;
      final totalMb = total ~/ 1024;
      return (usedMb, totalMb);
    } on IOException {
      return (0, 0);
    }
  }

  int _parseMemKb(String line) {
    // Format: "MemTotal:       3884032 kB"
    final parts = line.split(RegExp(r'\s+'));
    return int.tryParse(parts[1]) ?? 0;
  }

  Future<double> _readCpuLoad() async {
    try {
      final firstLine = await File('/proc/stat').readAsLines().then((l) => l.first);
      // Format: "cpu  user nice system idle iowait irq softirq steal ..."
      final parts = firstLine.split(RegExp(r'\s+')).skip(1).toList();
      final values = parts.map((s) => int.tryParse(s) ?? 0).toList();
      if (values.length < 5) return 0.0;

      final idle = values[3] + values[4]; // idle + iowait
      final total = values.fold(0, (a, b) => a + b);
      final tick = _CpuTick(total: total, idle: idle);

      final prev = _prevTick;
      _prevTick = tick;
      if (prev == null) return 0.0;

      final totalDelta = tick.total - prev.total;
      final idleDelta = tick.idle - prev.idle;
      if (totalDelta == 0) return 0.0;
      return ((totalDelta - idleDelta) / totalDelta).clamp(0.0, 1.0);
    } on IOException {
      return 0.0;
    }
  }
}

class _CpuTick {
  final int total;
  final int idle;
  const _CpuTick({required this.total, required this.idle});
}
