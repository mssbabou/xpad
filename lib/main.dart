import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'xpad.g.dart';

void main() {
  runApp(MouseRegion(
    cursor: kReleaseMode ? SystemMouseCursors.none : SystemMouseCursors.basic,
    child: MaterialApp(
      title: 'XPad',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
        /*textTheme: TextTheme(
          bodyMedium: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            decoration: TextDecoration.none, // kills the underline
          ),
          
        ),*/
      ),
      home: HomePage(),
    ),
  ));
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(8.0),
                      margin: EdgeInsets.all(16.0),
                      color: Colors.grey,
                      child: StreamBuilder(
                        stream: Stream.periodic(Duration(seconds: 1), (_) => DateTime.now()),
                        builder: (context, snapshot) {
                          final now = snapshot.data ?? DateTime.now();
                          final time = '${now.hour.toString().padLeft(2, '0')}.${now.minute.toString().padLeft(2, '0')}';
                          final date = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
      
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(time, style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 130)),
                              Text(date, style: Theme.of(context).textTheme.displayLarge),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(8.0),
                      margin: EdgeInsets.all(16.0),
                      color: Colors.grey,
                      child: Center(
                        child: TemperatureGauge(current: 10, min: 5, max: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(8.0),
                      margin: EdgeInsets.all(16.0),
                      color: Colors.grey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Text('21', style: Theme.of(context).textTheme.displayLarge),
                              Text('100%', style: Theme.of(context).textTheme.displayLarge),
                            ],
                          ),
                          SizedBox(
                            height: 40,
                            child: LinearGauge(value: 0.9),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(8.0),
                      margin: EdgeInsets.all(16.0),
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LinearGauge extends StatelessWidget {
  /// Current value in the range [0.0, 1.0].
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

  // Air-quality color scale: fresh → ok → musty → bad.
  // Non-linear stops: more room at the fresh end where rooms usually live,
  // tighter on the bad end so degradation feels urgent.
  static const _stops = <double>[0.00, 0.35, 0.70, 1.00];
  static const _colors = <Color>[
    Color(0xFF10B981), // emerald — fresh
    Color(0xFFFACC15), // amber — ok
    Color(0xFFF97316), // orange — musty
    Color(0xFFDC2626), // red — bad
  ];

  /// Sample the gradient at `t` in [0,1] by lerping between bracketing stops.
  static Color _sample(double t) {
    if (t <= _stops.first) return _colors.first;
    if (t >= _stops.last) return _colors.last;
    for (var i = 0; i < _stops.length - 1; i++) {
      final a = _stops[i];
      final b = _stops[i + 1];
      if (t <= b) {
        final local = (t - a) / (b - a);
        return Color.lerp(_colors[i], _colors[i + 1], local)!;
      }
    }
    return _colors.last;
  }

  @override
  void paint(Canvas canvas, Size size) {
    const barHeight = 22.0;

    final barTop = (size.height - barHeight) / 2;
    final radius = Radius.circular(barHeight / 2);
    final rect = Rect.fromLTWH(0, barTop, size.width, barHeight);
    final barRect = RRect.fromRectAndRadius(rect, radius);

    // Gradient spans the full bar width but is only revealed up to `value`.
    // This is what makes each state look different: at 10% the fill is pure
    // emerald; at 90% it reveals emerald → amber → orange. Low and high
    // values produce genuinely distinct silhouettes, not just "more filled."
    final gradient = LinearGradient(colors: _colors, stops: _stops);

    // Layer 1: soft outer glow tinted by the current severity. Drawn first so
    // the bar sits cleanly on top. Color is sampled at `value` so the whole
    // gauge warms/cools as it fills.
    if (value > 0) {
      final glowColor = _sample(value);
      final glowPaint = Paint()
        ..color = glowColor.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawRRect(barRect, glowPaint);
    }

    // Layer 2: neutral dark trough. No rainbow — the empty space stays empty
    // so the eye reads "how far has this progressed" instead of "what's the
    // whole spectrum."
    final troughPaint = Paint()..color = const Color(0xFF1E1E22);
    canvas.drawRRect(barRect, troughPaint);

    // Layer 3: opaque fill clipped to [0, value * width], drawing the gradient
    // spread across the FULL bar so only the left portion of the spectrum is
    // exposed at low values.
    if (value > 0) {
      canvas.save();
      canvas.clipRRect(barRect);
      final fillPaint = Paint()..shader = gradient.createShader(rect);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, barTop, size.width * value, barHeight),
          radius,
        ),
        fillPaint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant LinearGaugePainter old) => old.value != value;
}

class TemperatureGauge extends StatelessWidget {
  final double current;
  final double min;
  final double max;

  const TemperatureGauge({super.key, 
    required this.current,
    required this.min,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(200, 200),
      painter: GaugePainter(
        current: current,
        min: min,
        max: max,
      ),
    );
  }
}

class GaugePainter extends CustomPainter {
  final double current;
  final double min;
  final double max;

  GaugePainter({
    required this.current,
    required this.min,
    required this.max,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Background arc (3/4 circle, gap at bottom)
    final bgPaint = Paint()
      ..color = Color(0xFF333333)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    // 3/4 circle: starts at 135° (bottom-left), sweeps 270°
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      2.356, // 135° in radians
      4.712, // 270° in radians
      false,
      bgPaint,
    );

    // Pointer position
    final progress = (current - min) / (max - min);
    final angle = 2.356 + (progress * 4.712);

    final pointerEnd = Offset(
      center.dx + radius * cos(angle),
      center.dy + radius * sin(angle),
    );

    final pointerPaint = Paint()
      ..color = Color(0xFFFF6B35)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(pointerEnd, 6, pointerPaint);

    // Placeholder icon in the middle of the gauge.
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.thermostat.codePoint),
        style: TextStyle(
          color: const Color(0xFFFFFFFF),
          fontSize: 56,
          fontFamily: Icons.thermostat.fontFamily,
          package: Icons.thermostat.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    iconPainter.layout();
    iconPainter.paint(
      canvas,
      Offset(
        center.dx - iconPainter.width / 2,
        center.dy - iconPainter.height / 2 - 14,
      ),
    );

    // Current temperature, centered below the icon, between the min/max.
    final currentPainter = TextPainter(
      text: TextSpan(
        text: '${current.round()}°',
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 26,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    currentPainter.layout();
    currentPainter.paint(
      canvas,
      Offset(
        center.dx - currentPainter.width / 2,
        center.dy + 22,
      ),
    );

    // Min / max labels anchored to the arc endpoints.
    const labelStyle = TextStyle(
      color: Color.fromARGB(255, 255, 255, 255),
      fontSize: 20,
      fontWeight: FontWeight.w500,
    );

    final startPoint = Offset(
      center.dx + radius * cos(2.356),
      center.dy + radius * sin(2.356),
    );
    final endPoint = Offset(
      center.dx + radius * cos(2.356 + 4.712),
      center.dy + radius * sin(2.356 + 4.712),
    );

    final minPainter = TextPainter(
      text: TextSpan(text: '${min.round()}°', style: labelStyle),
      textDirection: TextDirection.ltr,
    );
    minPainter.layout();
    minPainter.paint(
      canvas,
      Offset(
        startPoint.dx - minPainter.width / 2,
        startPoint.dy + 6,
      ),
    );

    final maxPainter = TextPainter(
      text: TextSpan(text: '${max.round()}°', style: labelStyle),
      textDirection: TextDirection.ltr,
    );
    maxPainter.layout();
    maxPainter.paint(
      canvas,
      Offset(
        endPoint.dx - maxPainter.width / 2,
        endPoint.dy + 6,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant GaugePainter old) {
    return old.current != current || 
           old.min != min || 
           old.max != max;
  }
}