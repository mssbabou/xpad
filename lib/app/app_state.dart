import 'package:xpad/services/air_quality/air_quality_service.dart';
import 'package:xpad/services/display/display_service.dart';
import 'package:xpad/services/indoor/indoor_service.dart';
import 'package:xpad/services/location/location_service.dart';
import 'package:xpad/services/octoprint/octoprint_service.dart';
import 'package:xpad/services/system/system_service.dart';
import 'package:xpad/services/weather/weather_service.dart';
import 'package:xpad/widgets/keyboard_service.dart';

late WeatherService weather;
late AirQualityService airQuality;
late LocationService locationService;
late String kAppVersion;
final systemService = SystemService();
final octoprintService = OctoPrintService();
final keyboardService = KeyboardService();
final indoorSensorService = IndoorSensorService();
final displayService = DisplayService();
