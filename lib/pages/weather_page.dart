import 'package:flutter/material.dart';
import 'package:xpad/app/app_state.dart';
import 'package:xpad/app/theme.dart';
import 'package:xpad/services/air_quality/air_quality_service.dart';
import 'package:xpad/services/weather/weather_service.dart';
import 'package:xpad/widgets/dash_card.dart';
import 'package:xpad/widgets/weather_condition_icon.dart';

class WeatherPage extends StatelessWidget {
  const WeatherPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: StreamBuilder<Result<WeatherData>>(
        stream: weather.weatherStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: accent, strokeWidth: 2),
            );
          }
          return snapshot.data!.when(
            success: (data) => Column(
              children: [
                Expanded(flex: 3, child: _HeroSection(data: data)),
                const SizedBox(height: 16),
                Expanded(flex: 2, child: _ForecastCard(data: data)),
              ],
            ),
            failure: (e) => Center(
              child: Text(e.message, style: const TextStyle(color: textLo)),
            ),
          );
        },
      ),
    );
  }
}

// ── Hero ──────────────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final WeatherData data;
  const _HeroSection({required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left: temperature + condition
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(data.condition.icon, size: 36, color: textLo),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${data.currentTemperature.round()}',
                    style: const TextStyle(
                      color: textHi,
                      fontSize: 80,
                      fontWeight: FontWeight.w200,
                      height: 1,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text(
                      '°C',
                      style: TextStyle(
                        color: textLo,
                        fontSize: 22,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                data.condition.label,
                style: const TextStyle(
                  color: textLo,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),

        const VerticalDivider(color: border, thickness: 1, width: 48),

        // Right: 6 stat boxes in 2 rows of 3, square
        Expanded(
          flex: 3,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const gap = 8.0;
              final s = ((constraints.maxHeight - gap) / 2)
                  .clamp(0.0, (constraints.maxWidth - gap * 2) / 3);
              box(Widget child) => SizedBox(width: s, height: s, child: child);
              return Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      box(_StatBox(icon: Icons.keyboard_arrow_up_rounded,   label: 'High',       value: '${data.dailyMaxTemperature.round()}°C')),
                      box(_StatBox(icon: Icons.keyboard_arrow_down_rounded, label: 'Low',        value: '${data.dailyMinTemperature.round()}°C')),
                      box(_StatBox(icon: Icons.device_thermostat_rounded,   label: 'Feels like', value: '${data.apparentTemperature.round()}°C')),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      box(_StatBox(icon: Icons.water_drop_rounded, label: 'Humidity', value: '${data.relativeHumidity}%')),
                      box(const _UvBox()),
                      box(_SunBox(data: data)),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Forecast timeline ─────────────────────────────────────────────────────────

class _ForecastCard extends StatelessWidget {
  final WeatherData data;
  const _ForecastCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final hours = data.hourlyForecast.take(8).toList();
    return DashCard(
      label: 'Forecast',
      child: hours.isEmpty
          ? const Center(
              child: Text('No forecast data',
                  style: TextStyle(color: textLo, fontSize: 12)))
          : Row(
              children: hours
                  .map((h) => Expanded(
                        child: _HourColumn(
                          hour: h,
                          isNow: h == hours.first,
                        ),
                      ))
                  .toList(),
            ),
    );
  }
}

// ── Stat box ──────────────────────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatBox({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: textLo),
              const SizedBox(width: 5),
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: textLo,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            value,
            style: const TextStyle(
              color: textHi,
              fontSize: 17,
              fontWeight: FontWeight.w400,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── UV index box (reads from air quality service) ─────────────────────────────

class _UvBox extends StatelessWidget {
  const _UvBox();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Result<AirQualityData>>(
      stream: airQuality.airQualityStream(),
      builder: (context, snapshot) {
        final uv = snapshot.data?.when(
          success: (d) => d.uvIndex.round().toString(),
          failure: (_) => '—',
        ) ?? '—';
        return _StatBox(
          icon: Icons.light_mode_rounded,
          label: 'UV Index',
          value: uv,
        );
      },
    );
  }
}

// ── Sunrise/Sunset smart box ──────────────────────────────────────────────────

class _SunBox extends StatelessWidget {
  final WeatherData data;
  const _SunBox({required this.data});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final sunsetNext = now.isAfter(data.sunrise) && now.isBefore(data.sunset);

    final IconData nextIcon;
    final String nextLabel;
    final DateTime nextTime;
    final String otherLabel;
    final DateTime otherTime;

    if (sunsetNext) {
      nextIcon  = Icons.wb_twilight_rounded;
      nextLabel = 'Sunset';
      nextTime  = data.sunset;
      otherLabel = 'Sunrise';
      otherTime  = data.sunrise;
    } else {
      nextIcon  = Icons.wb_sunny_rounded;
      nextLabel = 'Sunrise';
      nextTime  = data.sunrise;
      otherLabel = 'Sunset';
      otherTime  = data.sunset;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(nextIcon, size: 13, color: textLo),
              const SizedBox(width: 5),
              Text(
                nextLabel.toUpperCase(),
                style: const TextStyle(
                  color: textLo,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            _hhmm(nextTime),
            style: const TextStyle(
              color: textHi,
              fontSize: 17,
              fontWeight: FontWeight.w400,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${otherLabel[0].toLowerCase()}${otherLabel.substring(1)} ${_hhmm(otherTime)}',
            style: const TextStyle(
              color: textLo,
              fontSize: 10,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hour column ───────────────────────────────────────────────────────────────

class _HourColumn extends StatelessWidget {
  final HourlyWeather hour;
  final bool isNow;
  const _HourColumn({required this.hour, required this.isNow});

  @override
  Widget build(BuildContext context) {
    final timeLabel = isNow
        ? 'Now'
        : '${hour.time.hour.toString().padLeft(2, '0')}:00';

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Text(
          timeLabel,
          style: TextStyle(
            color: isNow ? accent : textLo,
            fontSize: 13,
            fontWeight: isNow ? FontWeight.w600 : FontWeight.w400,
            letterSpacing: 0.3,
          ),
        ),
        Icon(hour.condition.icon, size: 26, color: isNow ? accent : textLo),
        Text(
          '${hour.temperature.round()}°',
          style: TextStyle(
            color: isNow ? textHi : textLo,
            fontSize: 24,
            fontWeight: isNow ? FontWeight.w400 : FontWeight.w300,
            height: 1,
          ),
        ),
        Text(
          hour.condition.label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: textLo, fontSize: 11, height: 1.3),
        ),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _hhmm(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
