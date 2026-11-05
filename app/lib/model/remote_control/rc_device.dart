class RcDevice {
  final String id;
  final String alias;
  final String ip;
  final int port;
  final bool requiresPin;
  final String os;

  const RcDevice({
    required this.id,
    required this.alias,
    required this.ip,
    this.port = 53317,
    this.requiresPin = false,
    this.os = 'Windows',
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RcDevice && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

