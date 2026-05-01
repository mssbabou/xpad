import 'package:flutter/material.dart';
import 'package:xpad/app/app_state.dart';
import 'package:xpad/app/theme.dart';
import 'package:xpad/services/air_quality/air_quality_service.dart';
import 'package:xpad/services/indoor/indoor_service.dart';
import 'package:xpad/widgets/dash_card.dart';
import 'package:xpad/widgets/gauges.dart';

class SmartHomePage extends StatelessWidget {
  const SmartHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IndoorSection(),
          const SizedBox(height: 14),
          Expanded(child: _LightsCard()),
        ],
      ),
    );
  }
}

// ── Indoor section ────────────────────────────────────────────────────────────

class _IndoorSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<IndoorData?>(
      stream: indoorSensorService.sensorStream(),
      builder: (context, snapshot) {
        final d = snapshot.data;
        final connected = d != null;
        final waiting = snapshot.connectionState == ConnectionState.waiting;

        final statusColor = waiting
            ? textLo.withValues(alpha: 0.4)
            : connected
                ? const Color(0xFF10B981)
                : const Color(0xFFDC2626);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Section label
            const Text(
              'SMART HOME',
              style: TextStyle(
                color: textLo,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 10),

            // Device row: sensor name + live status
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'ENS160 + AHT21',
                  style: TextStyle(
                    color: textHi,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Sensor readings — all chips, same size
            Row(
              children: [
                Expanded(child: _StatChip(
                  value: d != null ? d.temperature.toStringAsFixed(1) : '—',
                  unit: '°C',
                  label: 'Temp',
                )),
                const SizedBox(width: 10),
                Expanded(child: _StatChip(
                  value: d != null ? '${d.humidity.round()}' : '—',
                  unit: '%',
                  label: 'Humidity',
                )),
                const SizedBox(width: 10),
                Expanded(child: _StatChip(
                  value: d?.eco2 != null ? '${d!.eco2!.round()}' : '—',
                  unit: 'ppm',
                  label: 'eCO₂',
                )),
                const SizedBox(width: 10),
                Expanded(child: _StatChip(
                  value: d?.tvoc != null ? '${d!.tvoc!.round()}' : '—',
                  unit: 'ppb',
                  label: 'TVOC',
                )),
                const SizedBox(width: 10),
                Expanded(child: _StatChip(
                  value: d?.pressure != null ? '${d!.pressure!.round()}' : '—',
                  unit: 'hPa',
                  label: 'Pressure',
                )),
              ],
            ),
            const SizedBox(height: 18),

            // AQI bar
            SizedBox(
              height: 20,
              child: StreamBuilder<Result<AirQualityData>>(
                stream: airQuality.airQualityStream(),
                builder: (context, snapshot) {
                  final fraction = snapshot.data?.when(
                        success: (d) => d.aqiFraction,
                        failure: (_) => 0.0,
                      ) ??
                      0.0;
                  return LinearGauge(value: fraction);
                },
              ),
            ),
            const SizedBox(height: 5),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Fresh', style: TextStyle(color: textLo, fontSize: 11)),
                Text('Poor', style: TextStyle(color: textLo, fontSize: 11)),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ── Lights card ───────────────────────────────────────────────────────────────

class _LightsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DashCard(
      label: 'Lights',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.lightbulb_outline_rounded, color: textLo, size: 18),
          SizedBox(width: 10),
          Text(
            'Philips Hue — coming soon',
            style: TextStyle(color: textLo, fontSize: 13, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

// ── Stat chip ─────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String value;
  final String unit;
  final String label;

  const _StatChip({required this.value, required this.unit, required this.label});

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
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: textHi,
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                  height: 1,
                ),
              ),
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  unit,
                  style: const TextStyle(
                    color: textLo,
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: textLo,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
