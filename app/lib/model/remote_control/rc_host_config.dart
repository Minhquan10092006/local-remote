class RcHostConfig {
  final bool enabled;
  final String? pin;
  final int targetFps;
  final bool requireApproval;
  final int port;

  const RcHostConfig({
    this.enabled = true,
    this.pin,
    this.targetFps = 60,
    this.requireApproval = true,
    this.port = 53317,
  });

  RcHostConfig copyWith({
    bool? enabled,
    String? pin,
    int? targetFps,
    bool? requireApproval,
    int? port,
  }) {
    return RcHostConfig(
      enabled: enabled ?? this.enabled,
      pin: pin ?? this.pin,
      targetFps: targetFps ?? this.targetFps,
      requireApproval: requireApproval ?? this.requireApproval,
      port: port ?? this.port,
    );
  }
}

