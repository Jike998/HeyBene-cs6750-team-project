class NetworkSnapshot {
  const NetworkSnapshot({
    required this.running,
    required this.port,
    this.lastClientAddress,
  });

  final bool running;
  final int port;
  final String? lastClientAddress;
}
