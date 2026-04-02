class TelemetrySnapshot {
  const TelemetrySnapshot({
    required this.battery,
    required this.latency,
    required this.speed,
    required this.steering,
    required this.confidence,
    required this.voltage,
    required this.distance,
    required this.samples,
  });

  final int battery;
  final int latency;
  final double speed;
  final double steering;
  final int confidence;
  final double voltage;
  final double distance;
  final int samples;

  TelemetrySnapshot copyWith({
    int? battery,
    int? latency,
    double? speed,
    double? steering,
    int? confidence,
    double? voltage,
    double? distance,
    int? samples,
  }) {
    return TelemetrySnapshot(
      battery: battery ?? this.battery,
      latency: latency ?? this.latency,
      speed: speed ?? this.speed,
      steering: steering ?? this.steering,
      confidence: confidence ?? this.confidence,
      voltage: voltage ?? this.voltage,
      distance: distance ?? this.distance,
      samples: samples ?? this.samples,
    );
  }

  static const initial = TelemetrySnapshot(
    battery: 86,
    latency: 42,
    speed: 0.34,
    steering: 0.08,
    confidence: 91,
    voltage: 7.9,
    distance: 1.8,
    samples: 248,
  );
}
