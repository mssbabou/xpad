import 'dart:async';

import 'package:flutter/material.dart';
import 'package:xpad/app/theme.dart';
import 'package:xpad/pages/smart_home_page.dart';
import 'package:xpad/pages/weather_page.dart';
import 'package:xpad/pages/dashboard_page.dart';
import 'package:xpad/pages/octoprint_page.dart';
import 'package:xpad/pages/settings_page.dart';

class HomePage extends StatefulWidget {
  final VoidCallback onToggleOverlay;
  final bool showPerfOverlay;

  const HomePage({
    super.key,
    required this.onToggleOverlay,
    required this.showPerfOverlay,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _ctrl = PageController(initialPage: 1);
  int _page = 1;
  bool _dotsVisible = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onScroll);
  }

  void _onScroll() {
    final p = _ctrl.page?.round() ?? 0;
    if (p != _page) setState(() => _page = p);

    if (!_dotsVisible) setState(() => _dotsVisible = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _dotsVisible = false);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _ctrl.removeListener(_onScroll);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          PageView(
            controller: _ctrl,
            children: [
              const SmartHomePage(),
              const DashboardPage(),
              const WeatherPage(),
              const OctoPrintPage(),
              SettingsPage(
                onToggleOverlay: widget.onToggleOverlay,
                showPerfOverlay: widget.showPerfOverlay,
              ),
            ],
          ),
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: _dotsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _page
                        ? accent
                        : textLo.withValues(alpha: 0.3),
                  ),
                )),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
