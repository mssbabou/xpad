import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:xpad/app/app_state.dart';
import 'package:xpad/app/theme.dart';
import 'package:xpad/pages/home_page.dart';
import 'package:xpad/services/air_quality/air_quality_service.dart';
import 'package:xpad/services/location/location_service.dart';
import 'package:xpad/services/weather/weather_service.dart';
import 'package:xpad/widgets/keyboard_service.dart';
import 'package:xpad/widgets/on_screen_keyboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GestureBinding.instance.resamplingEnabled = true;

  final info = await PackageInfo.fromPlatform();
  kAppVersion = '${info.version}+${info.buildNumber}';

  await octoprintService.initialize();

  locationService = LocationService();
  final result = await locationService.getLocation();
  result.when(
    success: (loc) {
      weather = WeatherService(latitude: loc.latitude, longitude: loc.longitude);
      airQuality = AirQualityService(latitude: loc.latitude, longitude: loc.longitude);
    },
    failure: (error) => debugPrint(error.message),
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _showPerfOverlay = false;

  void _toggleOverlay() => setState(() => _showPerfOverlay = !_showPerfOverlay);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: kReleaseMode ? SystemMouseCursors.none : SystemMouseCursors.basic,
      child: MaterialApp(
        showPerformanceOverlay: _showPerfOverlay,
        title: 'XPad',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          scaffoldBackgroundColor: bg,
          colorScheme: const ColorScheme.light(surface: surface, primary: accent),
        ),
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
          },
        ),
        builder: (context, child) => ListenableBuilder(
          listenable: keyboardService,
          builder: (context, _) {
            final h = keyboardService.isVisible
                ? KeyboardService.keyboardHeight
                : 0.0;
            return Stack(
              children: [
                MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    viewInsets: EdgeInsets.only(bottom: h),
                  ),
                  child: child!,
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: OnScreenKeyboard(),
                ),
              ],
            );
          },
        ),
        home: HomePage(
          onToggleOverlay: _toggleOverlay,
          showPerfOverlay: _showPerfOverlay,
        ),
      ),
    );
  }
}
