import 'package:flutter/material.dart';
import 'package:xpad/app/theme.dart';

class DashCard extends StatelessWidget {
  final String label;
  final Widget child;

  const DashCard({super.key, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: textLo,
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
