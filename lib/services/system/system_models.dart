class SystemStats {
  final double cpuTempC;
  final double cpuLoadFrac;
  final int ramUsedMb;
  final int ramTotalMb;
  final Duration uptime;

  const SystemStats({
    required this.cpuTempC,
    required this.cpuLoadFrac,
    required this.ramUsedMb,
    required this.ramTotalMb,
    required this.uptime,
  });
}
