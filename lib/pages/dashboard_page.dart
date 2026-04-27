import 'package:flutter/material.dart';
import 'package:xpad/app/app_state.dart';
import 'package:xpad/app/theme.dart';
import 'package:xpad/services/system/system_models.dart';
import 'package:xpad/services/weather/weather_service.dart';
import 'package:xpad/widgets/dash_card.dart';
import 'package:xpad/widgets/gauges.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _ClockCard()),
                const SizedBox(width: 16),
                Expanded(child: _WeatherCard()),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _AirQualityCard()),
                const SizedBox(width: 16),
                Expanded(child: _SystemCard()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Clock ─────────────────────────────────────────────────────────────────────

class _ClockCard extends StatelessWidget {
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months   = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  @override
  Widget build(BuildContext context) {
    return DashCard(
      label: 'Time',
      child: StreamBuilder(
        stream: Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
        builder: (context, snapshot) {
          final now = snapshot.data ?? DateTime.now();
          final h = now.hour.toString().padLeft(2, '0');
          final m = now.minute.toString().padLeft(2, '0');
          final s = now.second.toString().padLeft(2, '0');
          final date =
              '${_weekdays[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]} ${now.year}';

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
                      fontSize: 82,
                      fontWeight: FontWeight.w200,
                      letterSpacing: -3,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      ':$s',
                      style: const TextStyle(
                        color: textLo,
                        fontSize: 30,
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
      ),
    );
  }
}

// ── Weather ───────────────────────────────────────────────────────────────────

class _WeatherCard extends StatelessWidget {
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
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => Center(
                      child: TemperatureGauge(
                        current: data.currentTemperature,
                        min: data.dailyMinTemperature,
                        max: data.dailyMaxTemperature,
                        size: constraints.maxHeight.clamp(80.0, 150.0),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${data.currentTemperature.round()}°C',
                      style: const TextStyle(
                        color: textHi,
                        fontSize: 32,
                        fontWeight: FontWeight.w200,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(data.condition.label, style: const TextStyle(color: textLo, fontSize: 13)),
                    const SizedBox(height: 16),
                    _Stat(label: 'Humidity', value: '${data.relativeHumidity}%'),
                  ],
                ),
              ],
            ),
            failure: (error) => Center(
              child: Text(error.message, style: const TextStyle(color: textLo)),
            ),
          );
        },
      ),
    );
  }
}

// ── Climate / Air Quality ─────────────────────────────────────────────────────

class _AirQualityCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DashCard(
      label: 'Climate',
      child: StreamBuilder<Result<WeatherData>>(
        stream: weather.weatherStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: accent, strokeWidth: 2));
          }
          return snapshot.data!.when(
            success: (data) => Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _BigStat(value: '${data.currentTemperature.round()}', unit: '°C', label: 'Temp'),
                    const SizedBox(width: 36),
                    _BigStat(value: '${data.relativeHumidity}', unit: '%', label: 'Humidity'),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20, child: LinearGauge(value: 0.9)),
                    const SizedBox(height: 6),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Fresh', style: TextStyle(color: textLo, fontSize: 11)),
                        Text('Poor',  style: TextStyle(color: textLo, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            failure: (error) => Center(
              child: Text(error.message, style: const TextStyle(color: textLo)),
            ),
          );
        },
      ),
    );
  }
}

// ── System ────────────────────────────────────────────────────────────────────

class _SystemCard extends StatefulWidget {
  @override
  State<_SystemCard> createState() => _SystemCardState();
}

class _SystemCardState extends State<_SystemCard> {
  late final Stream<SystemStats> _stream;

  @override
  void initState() {
    super.initState();
    _stream = systemService.statsStream();
  }

  @override
  Widget build(BuildContext context) {
    return DashCard(
      label: 'System',
      child: StreamBuilder<SystemStats>(
        stream: _stream,
        initialData: systemService.lastStats,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: accent, strokeWidth: 2));
          }
          final s = snapshot.data!;
          return Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _BigStat(
                    value: s.cpuTempC > 0 ? '${s.cpuTempC.round()}' : '—',
                    unit: '°C',
                    label: 'CPU Temp',
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _Stat(label: 'Uptime', value: _formatUptime(s.uptime)),
                  ),
                ],
              ),
              _SystemGaugeRow(
                label: 'CPU',
                frac: s.cpuLoadFrac,
                trailing: '${(s.cpuLoadFrac * 100).round()}%',
              ),
              _SystemGaugeRow(
                label: 'RAM',
                frac: s.ramTotalMb > 0 ? s.ramUsedMb / s.ramTotalMb : 0,
                trailing: '${_gb(s.ramUsedMb)} / ${_gb(s.ramTotalMb)} GB',
              ),
            ],
          );
        },
      ),
    );
  }

  static String _formatUptime(Duration d) {
    if (d.inDays >= 1) return '${d.inDays}d ${d.inHours.remainder(24)}h';
    return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
  }

  static String _gb(int mb) => (mb / 1024).toStringAsFixed(1);
}

// ── Shared display widgets ────────────────────────────────────────────────────

class _BigStat extends StatelessWidget {
  final String value;
  final String unit;
  final String label;
  const _BigStat({required this.value, required this.unit, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(value,
                style: const TextStyle(
                    color: textHi, fontSize: 44, fontWeight: FontWeight.w200, height: 1)),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Text(unit,
                  style: const TextStyle(color: textLo, fontSize: 15, fontWeight: FontWeight.w400)),
            ),
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

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: textLo, fontSize: 10, letterSpacing: 1.0, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text(value,
            style: const TextStyle(color: textHi, fontSize: 16, fontWeight: FontWeight.w400)),
      ],
    );
  }
}

class _SystemGaugeRow extends StatelessWidget {
  final String label;
  final double frac;
  final String trailing;
  const _SystemGaugeRow({required this.label, required this.frac, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    color: textLo, fontSize: 10, letterSpacing: 1.0, fontWeight: FontWeight.w600)),
            Text(trailing,
                style: const TextStyle(color: textHi, fontSize: 11, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(height: 8, child: _SystemBar(value: frac)),
      ],
    );
  }
}

class _SystemBar extends StatelessWidget {
  final double value;
  const _SystemBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SystemBarPainter(value: value.clamp(0.0, 1.0)),
      size: Size.infinite,
    );
  }
}

class _SystemBarPainter extends CustomPainter {
  final double value;
  const _SystemBarPainter({required this.value});

  static const _track = Color(0xFFE4E4EE);
  static const _fill  = Color(0xFF8888A8);

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    final rect   = Rect.fromLTWH(0, 0, size.width, size.height);
    final rRect  = RRect.fromRectAndRadius(rect, radius);

    canvas.drawRRect(rRect, Paint()..color = _track);

    if (value > 0) {
      canvas.save();
      canvas.clipRRect(rRect);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width * value, size.height),
          radius,
        ),
        Paint()..color = _fill,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SystemBarPainter old) => old.value != value;
}
