class AirQualityData {
  final int europeanAqi;
  final int usAqi;
  final double pm10;
  final double pm2_5;
  final double uvIndex;
  final double uvIndexClearSky;
  final double carbonMonoxide;
  final double nitrogenDioxide;
  final double sulphurDioxide;
  final double ozone;
  final double dust;
  final double aerosolOpticalDepth;
  final double? alderPollen;
  final double? birchPollen;
  final double? grassPollen;
  final double? mugwortPollen;
  final double? olivePollen;
  final double? ragweedPollen;
  final double? ammonia;
  final DateTime fetchedAt;

  const AirQualityData({
    required this.europeanAqi,
    required this.usAqi,
    required this.pm10,
    required this.pm2_5,
    required this.uvIndex,
    required this.uvIndexClearSky,
    required this.carbonMonoxide,
    required this.nitrogenDioxide,
    required this.sulphurDioxide,
    required this.ozone,
    required this.dust,
    required this.aerosolOpticalDepth,
    this.alderPollen,
    this.birchPollen,
    this.grassPollen,
    this.mugwortPollen,
    this.olivePollen,
    this.ragweedPollen,
    this.ammonia,
    required this.fetchedAt,
  });

  AirQualityLevel get level => AirQualityLevel.fromEuropeanAqi(europeanAqi);

  /// Normalised 0.0–1.0 value suitable for a LinearGauge (Good → Poor).
  double get aqiFraction => (europeanAqi / 100).clamp(0.0, 1.0);

  @override
  String toString() =>
      'AirQualityData(EU AQI: $europeanAqi, US AQI: $usAqi, UV: $uvIndex)';
}

enum AirQualityLevel {
  good,
  fair,
  moderate,
  poor,
  veryPoor,
  extremelyPoor;

  static AirQualityLevel fromEuropeanAqi(int aqi) {
    if (aqi <= 20) return AirQualityLevel.good;
    if (aqi <= 40) return AirQualityLevel.fair;
    if (aqi <= 60) return AirQualityLevel.moderate;
    if (aqi <= 80) return AirQualityLevel.poor;
    if (aqi <= 100) return AirQualityLevel.veryPoor;
    return AirQualityLevel.extremelyPoor;
  }

  String get label => switch (this) {
    AirQualityLevel.good           => 'Good',
    AirQualityLevel.fair           => 'Fair',
    AirQualityLevel.moderate       => 'Moderate',
    AirQualityLevel.poor           => 'Poor',
    AirQualityLevel.veryPoor       => 'Very Poor',
    AirQualityLevel.extremelyPoor  => 'Extremely Poor',
  };
}
