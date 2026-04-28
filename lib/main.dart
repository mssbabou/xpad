import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:xpad/app/app_state.dart';
import 'package:xpad/app/theme.dart';
import 'package:xpad/pages/home_page.dart';
import 'package:xpad/services/location/location_service.dart';
import 'package:xpad/services/spotify/spotify_service.dart';
import 'package:xpad/services/weather/weather_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GestureBinding.instance.resamplingEnabled = true;

  final info = await PackageInfo.fromPlatform();
  kAppVersion = '${info.version}+${info.buildNumber}';

  final location = LocationService();
  final result = await location.getLocation();
  result.when(
    success: (loc) {
      weather = WeatherService(latitude: loc.latitude, longitude: loc.longitude);
    },
    failure: (error) => debugPrint(error.message),
  );

  spotifyService = SpotifyService();
  await spotifyService.initialize();

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
        home: HomePage(
          onToggleOverlay: _toggleOverlay,
          showPerfOverlay: _showPerfOverlay,
        ),
      ),
    );
  }
}
