class ConnectionSnapshot {
  const ConnectionSnapshot({
    required this.bluetoothConnected,
    required this.usbConnected,
    required this.videoStable,
  });

  final bool bluetoothConnected;
  final bool usbConnected;
  final bool videoStable;

  ConnectionSnapshot copyWith({
    bool? bluetoothConnected,
    bool? usbConnected,
    bool? videoStable,
  }) {
    return ConnectionSnapshot(
      bluetoothConnected: bluetoothConnected ?? this.bluetoothConnected,
      usbConnected: usbConnected ?? this.usbConnected,
      videoStable: videoStable ?? this.videoStable,
    );
  }

  static const initial = ConnectionSnapshot(
    bluetoothConnected: false,
    usbConnected: false,
    videoStable: false,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConnectionSnapshot &&
        other.bluetoothConnected == bluetoothConnected &&
        other.usbConnected == usbConnected &&
        other.videoStable == videoStable;
  }

  @override
  int get hashCode => Object.hash(
        bluetoothConnected,
        usbConnected,
        videoStable,
      );
}
