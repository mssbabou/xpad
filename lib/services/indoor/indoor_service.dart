import 'indoor_models.dart';

export 'indoor_models.dart';

/// Provides indoor sensor data. Currently yields stub values — wire up real hardware here.
class IndoorSensorService {
  Stream<IndoorData?> sensorStream({
    Duration interval = const Duration(seconds: 30),
  }) async* {
    yield _stub();
    yield* Stream.periodic(interval).asyncMap((_) async => _stub());
  }

  IndoorData _stub() => IndoorData(
        temperature: 21.4,
        humidity: 58,
        eco2: 412,
        tvoc: 95,
        pressure: 1013.2,
        fetchedAt: DateTime.now(),
      );
}
