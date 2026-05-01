import 'package:flutter/material.dart';
import 'package:xpad/app/app_state.dart';
import 'package:xpad/app/theme.dart';
import 'package:xpad/services/air_quality/air_quality_service.dart';
import 'package:xpad/services/weather/weather_service.dart';
import 'package:xpad/widgets/dash_card.dart';
import 'package:xpad/widgets/gauges.dart';
import 'package:xpad/widgets/weather_condition_icon.dart';

class ClimatePage extends StatelessWidget {
  const ClimatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(child: _IndoorPollenBlock()),
          const SizedBox(height: 16),
          Expanded(child: _WeatherBlock()),
        ],
      ),
    );
  }
}

// ── Top block: Indoor climate + Pollen ───────────────────────────────────────

class _IndoorPollenBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DashCard(
      label: 'Indoor & Pollen',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 200,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _BigStat(value: '—', unit: '°C', label: 'Temp'),
                    const SizedBox(width: 28),
                    _BigStat(value: '—', unit: '%', label: 'Humidity'),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 20,
                      child: StreamBuilder<Result<AirQualityData>>(
                        stream: airQuality.airQualityStream(),
                        builder: (context, snapshot) {
                          final fraction = snapshot.data?.when(
                            success: (d) => d.aqiFraction,
                            failure: (_) => 0.0,
                          ) ?? 0.0;
                          return LinearGauge(value: fraction);
                        },
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Fresh', style: TextStyle(color: textLo, fontSize: 11)),
                        Text('Poor',  style: TextStyle(color: textLo, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
                const Text(
                  'No sensor connected',
                  style: TextStyle(color: textLo, fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: VerticalDivider(color: border, thickness: 1, width: 1),
          ),
          Expanded(
            child: StreamBuilder<Result<AirQualityData>>(
              stream: airQuality.airQualityStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(color: accent, strokeWidth: 2));
                }
                return snapshot.data!.when(
                  success: (data) {
                    final pollen = [
                      if (data.alderPollen   != null) _Pollen('Alder',   data.alderPollen!),
                      if (data.birchPollen   != null) _Pollen('Birch',   data.birchPollen!),
                      if (data.grassPollen   != null) _Pollen('Grass',   data.grassPollen!),
                      if (data.mugwortPollen != null) _Pollen('Mugwort', data.mugwortPollen!),
                      if (data.olivePollen   != null) _Pollen('Olive',   data.olivePollen!),
                      if (data.ragweedPollen != null) _Pollen('Ragweed', data.ragweedPollen!),
                    ].where((p) => p.value >= 1).toList();
                    if (pollen.isEmpty) {
                      return const Center(
                        child: Text(
                          'Pollen data unavailable\nin this region',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: textLo, fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      );
                    }
                    return Wrap(
                      spacing: 24,
                      runSpacing: 14,
                      runAlignment: WrapAlignment.center,
                      children: pollen
                          .map((p) => _PollenStat(name: p.name, value: p.value))
                          .toList(),
                    );
                  },
                  failure: (e) => Center(
                    child: Text(e.message,
                        style: const TextStyle(color: textLo, fontSize: 12)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Pollen {
  final String name;
  final double value;
  const _Pollen(this.name, this.value);
}

class _PollenStat extends StatelessWidget {
  final String name;
  final double value;
  const _PollenStat({required this.name, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(name,
            style: const TextStyle(
                color: textLo, fontSize: 10, letterSpacing: 1.0, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text('${value.round()} gr/m³',
            style: const TextStyle(color: textHi, fontSize: 16, fontWeight: FontWeight.w400)),
      ],
    );
  }
}

String _hhmm(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

// ── Bottom block: Current weather + Hourly columns ───────────────────────────

class _WeatherBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DashCard(
      label: 'Weather',
      child: StreamBuilder<Result<WeatherData>>(
        stream: weather.weatherStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: accent, strokeWidth: 2));
          }
          return snapshot.data!.when(
            success: (data) => Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Current conditions ──────────────────────────────────────
                SizedBox(
                  width: 150,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _WeatherStat(label: 'Sunrise', value: _hhmm(data.sunrise)),
                          const SizedBox(width: 20),
                          _WeatherStat(label: 'Sunset',  value: _hhmm(data.sunset)),
                        ],
                      ),
                      Row(
                        children: [
                          _WeatherStat(label: 'H', value: '${data.dailyMaxTemperature.round()}°'),
                          const SizedBox(width: 20),
                          _WeatherStat(label: 'L', value: '${data.dailyMinTemperature.round()}°'),
                        ],
                      ),
                      _WeatherStat(label: 'Feels like', value: '${data.apparentTemperature.round()}°C'),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: VerticalDivider(color: border, thickness: 1, width: 1),
                ),

                // ── Hourly columns ──────────────────────────────────────────
                Expanded(
                  child: data.hourlyForecast.isEmpty
                      ? const Center(
                          child: Text('No forecast data',
                              style: TextStyle(color: textLo, fontSize: 12)))
                      : Row(
                          children: data.hourlyForecast
                              .map((h) => Expanded(child: _HourColumn(hour: h, isNow: h == data.hourlyForecast.first)))
                              .toList(),
                        ),
                ),
              ],
            ),
            failure: (e) =>
                Center(child: Text(e.message, style: const TextStyle(color: textLo))),
          );
        },
      ),
    );
  }
}

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

class _WeatherStat extends StatelessWidget {
  final String label;
  final String value;
  const _WeatherStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(
                color: textLo,
                fontSize: 10,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text(value,
            style: const TextStyle(
                color: textHi, fontSize: 16, fontWeight: FontWeight.w400)),
      ],
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _BigStat extends StatelessWidget {
  final String value;
  final String unit;
  final String label;
  const _BigStat({required this.value, required this.unit, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                style: const TextStyle(
                    color: textHi, fontSize: 36, fontWeight: FontWeight.w200, height: 1)),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(unit,
                    style: const TextStyle(
                        color: textLo, fontSize: 13, fontWeight: FontWeight.w400)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: textLo, fontSize: 11, letterSpacing: 0.8, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
