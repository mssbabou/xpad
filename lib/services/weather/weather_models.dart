class HourlyWeather {
  final DateTime time;
  final double temperature;
  final WeatherCondition condition;

  const HourlyWeather({
    required this.time,
    required this.temperature,
    required this.condition,
  });
}

/// Immutable snapshot of current weather at a location.
/// Every field is non-nullable — a missing API value fails at parse time
/// rather than propagating nulls through the widget tree.
class WeatherData {
  final double currentTemperature;
  final double dailyMinTemperature;
  final double dailyMaxTemperature;
  final double apparentTemperature;
  final int relativeHumidity;
  final WeatherCondition condition;
  final List<HourlyWeather> hourlyForecast;
  final DateTime sunrise;
  final DateTime sunset;
  final DateTime fetchedAt;

  const WeatherData({
    required this.currentTemperature,
    required this.dailyMinTemperature,
    required this.dailyMaxTemperature,
    required this.apparentTemperature,
    required this.relativeHumidity,
    required this.condition,
    required this.hourlyForecast,
    required this.sunrise,
    required this.sunset,
    required this.fetchedAt,
  });

  @override
  String toString() =>
      'WeatherData($currentTemperature°C, '
      '${condition.label}, '
      'humidity $relativeHumidity%, '
      'min $dailyMinTemperature° max $dailyMaxTemperature°)';
}

/// WMO weather interpretation codes mapped to semantic conditions.
enum WeatherCondition {
  clearSky,
  mainlyClear,
  partlyCloudy,
  overcast,
  fog,
  drizzle,
  rain,
  freezingRain,
  snow,
  showers,
  thunderstorm;

  /// Parse a WMO weather code (0–99) into a [WeatherCondition].
  /// Unknown codes fall back to [clearSky] — the API can add new codes
  /// over time and we'd rather show "Clear Sky" than crash.
  static WeatherCondition fromWmoCode(int code) {
    return switch (code) {
      0               => WeatherCondition.clearSky,
      1               => WeatherCondition.mainlyClear,
      2               => WeatherCondition.partlyCloudy,
      3               => WeatherCondition.overcast,
      45 || 48        => WeatherCondition.fog,
      51 || 53 || 55  => WeatherCondition.drizzle,
      61 || 63 || 65  => WeatherCondition.rain,
      66 || 67        => WeatherCondition.freezingRain,
      71 || 73 || 75 || 77 => WeatherCondition.snow,
      80 || 81 || 82  => WeatherCondition.showers,
      85 || 86        => WeatherCondition.snow,
      95 || 96 || 99  => WeatherCondition.thunderstorm,
      _               => WeatherCondition.clearSky,
    };
  }

  /// Human-readable label for the UI.
  String get label => switch (this) {
    WeatherCondition.clearSky      => 'Clear Sky',
    WeatherCondition.mainlyClear   => 'Mainly Clear',
    WeatherCondition.partlyCloudy  => 'Partly Cloudy',
    WeatherCondition.overcast      => 'Overcast',
    WeatherCondition.fog           => 'Fog',
    WeatherCondition.drizzle       => 'Drizzle',
    WeatherCondition.rain          => 'Rain',
    WeatherCondition.freezingRain  => 'Freezing Rain',
    WeatherCondition.snow          => 'Snow',
    WeatherCondition.showers       => 'Showers',
    WeatherCondition.thunderstorm  => 'Thunderstorm',
  };
}
