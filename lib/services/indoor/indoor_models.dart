class IndoorData {
  final double temperature;
  final double humidity;
  final double? eco2;     // ppm
  final double? tvoc;     // ppb
  final double? pressure; // hPa
  final DateTime fetchedAt;

  const IndoorData({
    required this.temperature,
    required this.humidity,
    this.eco2,
    this.tvoc,
    this.pressure,
    required this.fetchedAt,
  });
}
