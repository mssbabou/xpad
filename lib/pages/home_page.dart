import 'package:flutter/material.dart';
import 'package:xpad/app/theme.dart';
import 'package:xpad/pages/dashboard_page.dart';
import 'package:xpad/pages/debug_page.dart';

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
      backgroundColor: bg,
      body: Stack(
        children: [
          PageView(
            controller: _ctrl,
            children: [
              const DashboardPage(),
              DebugPage(
                onToggleOverlay: widget.onToggleOverlay,
                showPerfOverlay: widget.showPerfOverlay,
              ),
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
                      ? accent
                      : textLo.withValues(alpha: 0.3),
                ),
              )),
            ),
          ),
        ],
      ),
    );
  }
}
