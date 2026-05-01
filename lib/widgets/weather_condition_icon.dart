import 'package:flutter/material.dart';
import 'package:xpad/services/weather/weather_models.dart';

extension WeatherConditionIcon on WeatherCondition {
  IconData get icon => switch (this) {
    WeatherCondition.clearSky      => Icons.wb_sunny,
    WeatherCondition.mainlyClear   => Icons.wb_sunny,
    WeatherCondition.partlyCloudy  => Icons.cloud_queue,
    WeatherCondition.overcast      => Icons.cloud,
    WeatherCondition.fog           => Icons.blur_on,
    WeatherCondition.drizzle       => Icons.grain,
    WeatherCondition.rain          => Icons.water_drop,
    WeatherCondition.freezingRain  => Icons.ac_unit,
    WeatherCondition.snow          => Icons.ac_unit,
    WeatherCondition.showers       => Icons.water_drop,
    WeatherCondition.thunderstorm  => Icons.thunderstorm,
  };
}
