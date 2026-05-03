class HueLightState {
  final bool on;
  final int brightness;

  const HueLightState({required this.on, required this.brightness});

  factory HueLightState.fromJson(Map<String, dynamic> json) => HueLightState(
        on: json['on'] as bool? ?? false,
        brightness: json['bri'] as int? ?? 0,
      );

  HueLightState copyWith({bool? on}) =>
      HueLightState(on: on ?? this.on, brightness: brightness);
}

class HueLight {
  final String id;
  final String name;
  final HueLightState state;

  const HueLight({required this.id, required this.name, required this.state});

  HueLight copyWith({HueLightState? state}) =>
      HueLight(id: id, name: name, state: state ?? this.state);
}
