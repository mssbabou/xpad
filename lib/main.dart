import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:xpad/app/app_state.dart';
import 'package:xpad/app/theme.dart';
import 'package:xpad/pages/page_shell.dart';
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
  await hueService.initialize();

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
  final _showPerfOverlay = ValueNotifier(false);

  @override
  void dispose() {
    _showPerfOverlay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _showPerfOverlay,
      builder: (context, showOverlay, _) => MaterialApp(
        showPerformanceOverlay: showOverlay,
        title: 'XPad',
        debugShowCheckedModeBanner: false,
        navigatorObservers: [routeObserver],
        theme: ThemeData(
          fontFamily: 'Adwaita Sans',
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
                if (kReleaseMode)
                  MouseRegion(
                    cursor: SystemMouseCursors.none,
                    opaque: false,
                    child: const SizedBox.expand(),
                  ),
              ],
            );
          },
        ),
        home: PageShell(showPerfOverlay: _showPerfOverlay),
      ),
    );
  }
}
