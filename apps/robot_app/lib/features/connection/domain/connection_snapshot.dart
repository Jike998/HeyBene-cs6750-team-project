class ConnectionSnapshot {
  const ConnectionSnapshot({
    required this.bluetoothConnected,
    required this.usbConnected,
    required this.videoStable,
    this.webSocketConnected = false,
    this.webSocketTarget,
    this.pcConnected = false,
    this.pcLinkPort,
    this.pcClientAddress,
  });

  static const _unset = Object();

  final bool bluetoothConnected;
  final bool usbConnected;
  final bool videoStable;
  final bool webSocketConnected;
  final String? webSocketTarget;
  final bool pcConnected;
  final int? pcLinkPort;
  final String? pcClientAddress;

  ConnectionSnapshot copyWith({
    bool? bluetoothConnected,
    bool? usbConnected,
    bool? videoStable,
    bool? webSocketConnected,
    Object? webSocketTarget = _unset,
    bool? pcConnected,
    Object? pcLinkPort = _unset,
    Object? pcClientAddress = _unset,
  }) {
    return ConnectionSnapshot(
      bluetoothConnected: bluetoothConnected ?? this.bluetoothConnected,
      usbConnected: usbConnected ?? this.usbConnected,
      videoStable: videoStable ?? this.videoStable,
      webSocketConnected: webSocketConnected ?? this.webSocketConnected,
      webSocketTarget: identical(webSocketTarget, _unset)
          ? this.webSocketTarget
          : webSocketTarget as String?,
      pcConnected: pcConnected ?? this.pcConnected,
      pcLinkPort: identical(pcLinkPort, _unset) ? this.pcLinkPort : pcLinkPort as int?,
      pcClientAddress: identical(pcClientAddress, _unset) ? this.pcClientAddress : pcClientAddress as String?,
    );
  }

  static const initial = ConnectionSnapshot(
    bluetoothConnected: false,
    usbConnected: false,
    videoStable: false,
    webSocketConnected: false,
    webSocketTarget: null,
    pcConnected: false,
    pcLinkPort: null,
    pcClientAddress: null,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConnectionSnapshot &&
        other.bluetoothConnected == bluetoothConnected &&
        other.usbConnected == usbConnected &&
        other.videoStable == videoStable &&
        other.webSocketConnected == webSocketConnected &&
        other.webSocketTarget == webSocketTarget &&
        other.pcConnected == pcConnected &&
        other.pcLinkPort == pcLinkPort &&
        other.pcClientAddress == pcClientAddress;
  }

  @override
  int get hashCode => Object.hash(
        bluetoothConnected,
        usbConnected,
        videoStable,
        webSocketConnected,
        webSocketTarget,
        pcConnected,
        pcLinkPort,
        pcClientAddress,
      );
}
