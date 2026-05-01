import 'package:flutter/material.dart';
import 'package:xpad/app/app_state.dart';
import 'package:xpad/app/theme.dart';
import 'package:xpad/services/air_quality/air_quality_service.dart';
import 'package:xpad/services/weather/weather_service.dart';
import 'package:xpad/widgets/gauges.dart';
import 'package:xpad/widgets/weather_condition_icon.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _Clock(),
            ),
          ),
          const SizedBox(width: 48),
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _WeatherSnippet(),
                _MustinessSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Clock ─────────────────────────────────────────────────────────────────────

class _Clock extends StatelessWidget {
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months   = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
      builder: (context, snapshot) {
        final now  = snapshot.data ?? DateTime.now();
        final h    = now.hour.toString().padLeft(2, '0');
        final m    = now.minute.toString().padLeft(2, '0');
        final s    = now.second.toString().padLeft(2, '0');
        final date = '${_weekdays[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]} ${now.year}';

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$h:$m',
                  style: const TextStyle(
                    color: textHi,
                    fontSize: 117,
                    fontWeight: FontWeight.w200,
                    letterSpacing: -4,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    ':$s',
                    style: const TextStyle(
                      color: textLo,
                      fontSize: 42,
                      fontWeight: FontWeight.w300,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              date,
              style: const TextStyle(
                color: textLo,
                fontSize: 17,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.3,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Weather snippet ───────────────────────────────────────────────────────────

class _WeatherSnippet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Result<WeatherData>>(
      stream: weather.weatherStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator(color: textLo, strokeWidth: 1.5)),
          );
        }
        return snapshot.data!.when(
          success: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(data.condition.icon, size: 40, color: textLo),
              const SizedBox(height: 8),
              Text(
                '${data.currentTemperature.round()}°C',
                style: const TextStyle(
                  color: textHi,
                  fontSize: 36,
                  fontWeight: FontWeight.w200,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.condition.label,
                style: const TextStyle(color: textLo, fontSize: 13),
              ),
            ],
          ),
          failure: (e) => Text(e.message, style: const TextStyle(color: textLo, fontSize: 13)),
        );
      },
    );
  }
}

// ── Mustiness gauge ───────────────────────────────────────────────────────────

class _MustinessSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Result<AirQualityData>>(
      stream: airQuality.airQualityStream(),
      builder: (context, snapshot) {
        final value = snapshot.data?.when(
          success: (data) => data.aqiFraction,
          failure: (_) => 0.0,
        ) ?? 0.0;

        return LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.maxWidth.clamp(80.0, 180.0);
            return MustinessGauge(value: value, size: size);
          },
        );
      },
    );
  }
}
