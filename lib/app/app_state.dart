import 'package:xpad/services/octoprint/octoprint_service.dart';
import 'package:xpad/services/system/system_service.dart';
import 'package:xpad/services/weather/weather_service.dart';
import 'package:xpad/widgets/keyboard_service.dart';

late WeatherService weather;
late String kAppVersion;
final systemService = SystemService();
final octoprintService = OctoPrintService();
final keyboardService = KeyboardService();
