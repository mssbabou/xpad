import 'dart:async';

import 'package:flutter/material.dart';
import 'package:xpad/app/app_state.dart';
import 'package:xpad/app/theme.dart';
import 'package:xpad/pages/smart_home_page.dart';
import 'package:xpad/pages/weather_page.dart';
import 'package:xpad/pages/home_page.dart';
import 'package:xpad/pages/octoprint_page.dart';
import 'package:xpad/pages/settings_page.dart';

class PageShell extends StatefulWidget {
  final VoidCallback onToggleOverlay;
  final bool showPerfOverlay;

  const PageShell({
    super.key,
    required this.onToggleOverlay,
    required this.showPerfOverlay,
  });

  @override
  State<PageShell> createState() => _PageShellState();
}

class _PageShellState extends State<PageShell> with RouteAware {
  final _ctrl = PageController(initialPage: 1);
  int _page = 1;
  bool _dotsVisible = false;
  Timer? _hideTimer;
  Timer? _inactivityTimer;
  bool _returnEnabled = true;
  int _returnDelaySeconds = 300;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onScroll);
    _loadReturnConfig();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPushNext() => _inactivityTimer?.cancel();

  @override
  void didPopNext() => _resetInactivityTimer();

  Future<void> _loadReturnConfig() async {
    final enabled = await displayService.getReturnToHome();
    final delay = await displayService.getReturnDelay();
    if (!mounted) return;
    _returnEnabled = enabled;
    _returnDelaySeconds = delay;
    _resetInactivityTimer();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    if (!_returnEnabled) return;
    _inactivityTimer = Timer(Duration(seconds: _returnDelaySeconds), _goHome);
  }

  void _goHome() {
    if (!mounted || _ctrl.page?.round() == 1) return;
    _ctrl.animateToPage(1,
        duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
  }

  void _onScroll() {
    final p = _ctrl.page?.round() ?? 0;
    if (p != _page) {
      setState(() => _page = p);
      if (_page != 4) _loadReturnConfig();
    }

    if (!_dotsVisible) setState(() => _dotsVisible = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _dotsVisible = false);
    });
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _hideTimer?.cancel();
    _inactivityTimer?.cancel();
    _ctrl.removeListener(_onScroll);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _resetInactivityTimer(),
      child: Scaffold(
        backgroundColor: bg,
        body: Stack(
          children: [
            PageView(
              controller: _ctrl,
              children: [
                const SmartHomePage(),
                const HomePage(),
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
      ),
    );
  }
}
