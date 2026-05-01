import 'dart:math';
import 'package:flutter/material.dart';
import 'package:xpad/app/theme.dart';

// ── Linear (air-quality) gauge ────────────────────────────────────────────────

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

// ── Mustiness arc gauge ───────────────────────────────────────────────────────

class MustinessGauge extends StatelessWidget {
  final double value;
  final double size;

  const MustinessGauge({super.key, required this.value, this.size = 150});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _MustinessGaugePainter(value: value.clamp(0.0, 1.0)),
    );
  }
}

class _MustinessGaugePainter extends CustomPainter {
  final double value;

  _MustinessGaugePainter({required this.value});

  static const _trackColor = Color(0xFFE0E0EA);
  static const _fillStart  = Color(0xFFCDD0E6);
  static const _fillEnd    = Color(0xFF6870B8);
  static const _dotColor   = Color(0xFF8888A8);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const startAngle = 2.356;
    const sweep     = 4.712;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle, sweep, false,
      Paint()
        ..color = _trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );

    if (value > 0) {
      final arcRect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(
        arcRect, startAngle, sweep * value, false,
        Paint()
          ..shader = LinearGradient(colors: [_fillStart, _fillEnd])
              .createShader(arcRect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round,
      );
    }

    final angle     = startAngle + value * sweep;
    final dotCenter = Offset(
      center.dx + radius * cos(angle),
      center.dy + radius * sin(angle),
    );
    canvas.drawCircle(dotCenter, 6, Paint()..color = _dotColor);
    canvas.drawCircle(dotCenter, 3, Paint()..color = Colors.white);

    const labelStyle = TextStyle(color: textLo, fontSize: 12, fontWeight: FontWeight.w400);
    final startPt = Offset(center.dx + radius * cos(startAngle), center.dy + radius * sin(startAngle));
    final endPt   = Offset(center.dx + radius * cos(startAngle + sweep), center.dy + radius * sin(startAngle + sweep));

    final freshP = TextPainter(
      text: const TextSpan(text: 'Fresh', style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    freshP.paint(canvas, Offset(startPt.dx - freshP.width / 2, startPt.dy + 6));

    final poorP = TextPainter(
      text: const TextSpan(text: 'Poor', style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    poorP.paint(canvas, Offset(endPt.dx - poorP.width / 2, endPt.dy + 6));
  }

  @override
  bool shouldRepaint(covariant _MustinessGaugePainter old) => old.value != value;
}

// ── Temperature arc gauge ─────────────────────────────────────────────────────

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
      painter: TemperatureGaugePainter(current: current, min: min, max: max),
    );
  }
}

class TemperatureGaugePainter extends CustomPainter {
  final double current;
  final double min;
  final double max;

  TemperatureGaugePainter({required this.current, required this.min, required this.max});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

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

    final progress = ((current - min) / (max - min)).clamp(0.0, 1.0);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        2.356,
        4.712 * progress,
        false,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF4488FF), Color(0xFFFF6B35)],
          ).createShader(Rect.fromCircle(center: center, radius: radius))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round,
      );
    }

    final angle = 2.356 + progress * 4.712;
    final pointerEnd = Offset(
      center.dx + radius * cos(angle),
      center.dy + radius * sin(angle),
    );
    canvas.drawCircle(pointerEnd, 7, Paint()..color = accent);
    canvas.drawCircle(pointerEnd, 3, Paint()..color = textHi);

    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.thermostat.codePoint),
        style: TextStyle(
          color: textLo,
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

    final currentPainter = TextPainter(
      text: TextSpan(
        text: '${current.round()}°',
        style: const TextStyle(color: textHi, fontSize: 24, fontWeight: FontWeight.w500),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    currentPainter.paint(
      canvas,
      Offset(center.dx - currentPainter.width / 2, center.dy + 20),
    );

    const labelStyle = TextStyle(color: textLo, fontSize: 13, fontWeight: FontWeight.w400);
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
  bool shouldRepaint(covariant TemperatureGaugePainter old) =>
      old.current != current || old.min != min || old.max != max;
}
