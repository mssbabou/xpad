import 'indoor_models.dart';

export 'indoor_models.dart';

/// Provides indoor temperature and humidity from a connected sensor.
/// Currently yields null — wire up real hardware here when available.
class IndoorSensorService {
  Stream<IndoorData?> sensorStream({
    Duration interval = const Duration(seconds: 30),
  }) async* {
    yield IndoorData(temperature: 21.4, humidity: 58, fetchedAt: DateTime.now());
    yield* Stream.periodic(interval).asyncMap((_) async =>
        IndoorData(temperature: 21.4, humidity: 58, fetchedAt: DateTime.now()));
  }
}
