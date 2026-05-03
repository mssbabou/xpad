enum PrinterState { offline, operational, printing, pausing, paused, cancelling, error, unknown }

class OctoPrintTemperature {
  final double actual;
  final double target;
  const OctoPrintTemperature({required this.actual, required this.target});
}

class OctoPrintStatus {
  final PrinterState state;
  final OctoPrintJob? job;
  final OctoPrintTemperature? hotend;
  final OctoPrintTemperature? bed;

  const OctoPrintStatus({required this.state, this.job, this.hotend, this.bed});

  bool get isActive =>
      state == PrinterState.printing ||
      state == PrinterState.pausing ||
      state == PrinterState.paused ||
      state == PrinterState.cancelling;
}

class PreheatPreset {
  final String label;
  final int hotend;
  final int bed;
  const PreheatPreset(this.label, this.hotend, this.bed);
}

const preheatPresets = [
  PreheatPreset('PLA',  200, 60),
  PreheatPreset('PETG', 240, 70),
  PreheatPreset('ABS',  250, 100),
  PreheatPreset('TPU',  220, 40),
];

class OctoPrintJob {
  final String filename;
  final double completion;
  final int printTimeSeconds;
  final int? printTimeLeftSeconds;

  const OctoPrintJob({
    required this.filename,
    required this.completion,
    required this.printTimeSeconds,
    this.printTimeLeftSeconds,
  });
}

class OctoPrintFile {
  final String name;
  final String path;
  final int? sizeBytes;
  final int? estimatedPrintTimeSeconds;

  const OctoPrintFile({
    required this.name,
    required this.path,
    this.sizeBytes,
    this.estimatedPrintTimeSeconds,
  });
}
