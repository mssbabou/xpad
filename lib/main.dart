import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:xpad/services/location/location_service.dart';
import 'package:xpad/services/weather/weather_service.dart';

late WeatherService weather;

// ── Palette ─────────────────────────────────────────────────────────────────
const _bg      = Color(0xFFF0F0F5);
const _surface = Color(0xFFFFFFFF);
const _border  = Color(0xFFDDDDE8);
const _textHi  = Color(0xFF18182A);
const _textLo  = Color(0xFF8888A8);
const _accent  = Color(0xFFFF6B35);

Future<void> main() async {
  final location = LocationService();
  final result = await location.getLocation();
  result.when(
    success: (loc) {
      weather = WeatherService(latitude: loc.latitude, longitude: loc.longitude);
    },
    failure: (error) => print(error.message),
  );

  runApp(MouseRegion(
    cursor: kReleaseMode ? SystemMouseCursors.none : SystemMouseCursors.basic,
    child: MaterialApp(
      title: 'XPad',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: _bg,
        colorScheme: const ColorScheme.light(surface: _surface, primary: _accent),
      ),
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
        },
      ),
      home: const HomePage(),
    ),
  ));
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _ctrl = PageController();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final p = _ctrl.page?.round() ?? 0;
      if (p != _page) setState(() => _page = p);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          PageView(
            controller: _ctrl,
            children: const [
              _DashboardPage(),
              _SecondPage(),
            ],
          ),
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(2, (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _page
                      ? _accent
                      : _textLo.withValues(alpha: 0.3),
                ),
              )),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardPage extends StatelessWidget {
  const _DashboardPage();

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

class _SecondPage extends StatelessWidget {
  const _SecondPage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Page 2',
        style: TextStyle(color: _textLo, fontSize: 22, fontWeight: FontWeight.w300),
      ),
    );
  }
}

// ── Shared card shell ────────────────────────────────────────────────────────

class _DashCard extends StatelessWidget {
  final String label;
  final Widget child;

  const _DashCard({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: _textLo,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(child: child),
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
    return _DashCard(
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
                      color: _textHi,
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
                        color: _textLo,
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
                  color: _textLo,
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

// ── Weather ──────────────────────────────────────────────────────────────────

class _WeatherCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _DashCard(
      label: 'Weather',
      child: StreamBuilder<Result<WeatherData>>(
        stream: weather.weatherStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _accent, strokeWidth: 2),
            );
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
                        color: _textHi,
                        fontSize: 32,
                        fontWeight: FontWeight.w200,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.condition.label,
                      style: const TextStyle(color: _textLo, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    _WeatherStat(label: 'Humidity', value: '${data.relativeHumidity}%'),
                  ],
                ),
              ],
            ),
            failure: (error) => Center(
              child: Text(error.message, style: const TextStyle(color: _textLo)),
            ),
          );
        },
      ),
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
      children: [
        Text(label,
            style: const TextStyle(color: _textLo, fontSize: 10, letterSpacing: 1.0, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text(value,
            style: const TextStyle(color: _textHi, fontSize: 16, fontWeight: FontWeight.w400)),
      ],
    );
  }
}

// ── Climate ───────────────────────────────────────────────────────────────────

class _AirQualityCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _DashCard(
      label: 'Climate',
      child: StreamBuilder<Result<WeatherData>>(
        stream: weather.weatherStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _accent, strokeWidth: 2),
            );
          }
          return snapshot.data!.when(
            success: (data) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _BigStat(
                        value: '${data.currentTemperature.round()}',
                        unit: '°C',
                        label: 'Temp',
                      ),
                      const SizedBox(width: 36),
                      _BigStat(
                        value: '${data.relativeHumidity}',
                        unit: '%',
                        label: 'Humidity',
                      ),
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
                          Text('Fresh', style: TextStyle(color: _textLo, fontSize: 11)),
                          Text('Poor', style: TextStyle(color: _textLo, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ],
              );
            },
            failure: (error) => Center(
              child: Text(error.message, style: const TextStyle(color: _textLo)),
            ),
          );
        },
      ),
    );
  }
}

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
                    color: _textHi, fontSize: 44, fontWeight: FontWeight.w200, height: 1)),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Text(unit,
                  style: const TextStyle(
                      color: _textLo, fontSize: 15, fontWeight: FontWeight.w400)),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: _textLo, fontSize: 11, letterSpacing: 0.8, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ── System placeholder ────────────────────────────────────────────────────────

class _SystemCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const _DashCard(
      label: 'System',
      child: Center(
        child: Text('—', style: TextStyle(color: _textLo, fontSize: 28)),
      ),
    );
  }
}

// ── Linear gauge ──────────────────────────────────────────────────────────────

class LinearGauge extends StatelessWidget {
  final double value;
  const LinearGauge({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: LinearGaugePainter(value: value.clamp(0.0, 1.0)),
      size: Size.infinite,
    );
  }
}

class LinearGaugePainter extends CustomPainter {
  final double value;

  LinearGaugePainter({required this.value});

  static const _stops  = <double>[0.00, 0.35, 0.70, 1.00];
  static const _colors = <Color>[
    Color(0xFF10B981),
    Color(0xFFFACC15),
    Color(0xFFF97316),
    Color(0xFFDC2626),
  ];

  static Color _sample(double t) {
    if (t <= _stops.first) return _colors.first;
    if (t >= _stops.last)  return _colors.last;
    for (var i = 0; i < _stops.length - 1; i++) {
      final a = _stops[i], b = _stops[i + 1];
      if (t <= b) return Color.lerp(_colors[i], _colors[i + 1], (t - a) / (b - a))!;
    }
    return _colors.last;
  }

  @override
  void paint(Canvas canvas, Size size) {
    const barHeight = 20.0;
    final barTop = (size.height - barHeight) / 2;
    final radius = Radius.circular(barHeight / 2);
    final rect = Rect.fromLTWH(0, barTop, size.width, barHeight);
    final barRect = RRect.fromRectAndRadius(rect, radius);

    if (value > 0) {
      final glowPaint = Paint()
        ..color = _sample(value).withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawRRect(barRect, glowPaint);
    }

    canvas.drawRRect(barRect, Paint()..color = const Color(0xFFE4E4EE));

    if (value > 0) {
      canvas.save();
      canvas.clipRRect(barRect);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, barTop, size.width * value, barHeight),
          radius,
        ),
        Paint()
          ..shader = const LinearGradient(colors: _colors, stops: _stops).createShader(rect),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant LinearGaugePainter old) => old.value != value;
}

// ── Temperature gauge ─────────────────────────────────────────────────────────

class TemperatureGauge extends StatelessWidget {
  final double current;
  final double min;
  final double max;
  final double size;

  const TemperatureGauge({
    super.key,
    required this.current,
    required this.min,
    required this.max,
    this.size = 150,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: GaugePainter(current: current, min: min, max: max),
    );
  }
}

class GaugePainter extends CustomPainter {
  final double current;
  final double min;
  final double max;

  GaugePainter({required this.current, required this.min, required this.max});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    // Background track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      2.356,
      4.712,
      false,
      Paint()
        ..color = const Color(0xFFE0E0EA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );

    // Filled arc up to current value
    final progress = ((current - min) / (max - min)).clamp(0.0, 1.0);
    if (progress > 0) {
      final arcPaint = Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF4488FF), Color(0xFFFF6B35)],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        2.356,
        4.712 * progress,
        false,
        arcPaint,
      );
    }

    // Pointer dot
    final angle = 2.356 + progress * 4.712;
    final pointerEnd = Offset(
      center.dx + radius * cos(angle),
      center.dy + radius * sin(angle),
    );
    canvas.drawCircle(
        pointerEnd, 7, Paint()..color = _accent);
    canvas.drawCircle(
        pointerEnd, 3, Paint()..color = _textHi);

    // Thermostat icon
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.thermostat.codePoint),
        style: TextStyle(
          color: _textLo,
          fontSize: 48,
          fontFamily: Icons.thermostat.fontFamily,
          package: Icons.thermostat.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    iconPainter.paint(
      canvas,
      Offset(center.dx - iconPainter.width / 2, center.dy - iconPainter.height / 2 - 14),
    );

    // Current temperature
    final currentPainter = TextPainter(
      text: TextSpan(
        text: '${current.round()}°',
        style: const TextStyle(
          color: _textHi,
          fontSize: 24,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    currentPainter.paint(
      canvas,
      Offset(center.dx - currentPainter.width / 2, center.dy + 20),
    );

    // Min / max labels
    const labelStyle = TextStyle(color: _textLo, fontSize: 13, fontWeight: FontWeight.w400);

    final startPt = Offset(center.dx + radius * cos(2.356), center.dy + radius * sin(2.356));
    final endPt   = Offset(center.dx + radius * cos(2.356 + 4.712), center.dy + radius * sin(2.356 + 4.712));

    final minP = TextPainter(
      text: TextSpan(text: '${min.round()}°', style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    minP.paint(canvas, Offset(startPt.dx - minP.width / 2, startPt.dy + 6));

    final maxP = TextPainter(
      text: TextSpan(text: '${max.round()}°', style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    maxP.paint(canvas, Offset(endPt.dx - maxP.width / 2, endPt.dy + 6));
  }

  @override
  bool shouldRepaint(covariant GaugePainter old) =>
      old.current != current || old.min != min || old.max != max;
}
