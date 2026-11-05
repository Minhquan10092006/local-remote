import 'dart:async';
import 'package:refena_flutter/refena_flutter.dart';
import '../../model/remote_control/rc_host_config.dart';
import '../../model/remote_control/rc_session_state.dart';

class RcHostState {
  final RcHostStatus status;
  final RcHostConfig config;
  final String? clientAlias;
  final DateTime? connectedSince;
  final Duration sessionDuration;

  const RcHostState({
    this.status = RcHostStatus.idle,
    this.config = const RcHostConfig(),
    this.clientAlias,
    this.connectedSince,
    this.sessionDuration = Duration.zero,
  });

  RcHostState copyWith({
    RcHostStatus? status,
    RcHostConfig? config,
    String? clientAlias,
    bool clearClient = false,
    DateTime? connectedSince,
    Duration? sessionDuration,
  }) {
    return RcHostState(
      status: status ?? this.status,
      config: config ?? this.config,
      clientAlias: clearClient ? null : (clientAlias ?? this.clientAlias),
      connectedSince: clearClient ? null : (connectedSince ?? this.connectedSince),
      sessionDuration: clearClient ? Duration.zero : (sessionDuration ?? this.sessionDuration),
    );
  }
}

class RcHostNotifier extends Notifier<RcHostState> {
  Timer? _timer;

  @override
  RcHostState init() {
    return const RcHostState();
  }

  void startListening() {
    state = state.copyWith(status: RcHostStatus.listening);
  }

  void stopListening() {
    _timer?.cancel();
    _timer = null;
    state = state.copyWith(
      status: RcHostStatus.idle,
      clearClient: true,
    );
  }

  void onClientConnecting(String alias) {
    if (state.config.requireApproval) {
      state = state.copyWith(
        status: RcHostStatus.awaitingApproval,
        clientAlias: alias,
      );
    } else {
      acceptClient(alias);
    }
  }

  void acceptClient([String? alias]) {
    final now = DateTime.now();
    state = state.copyWith(
      status: RcHostStatus.activeSession,
      clientAlias: alias ?? state.clientAlias ?? 'Android Client',
      connectedSince: now,
      sessionDuration: Duration.zero,
    );

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.connectedSince != null) {
        state = state.copyWith(
          sessionDuration: DateTime.now().difference(state.connectedSince!),
        );
      }
    });
  }

  void rejectClient() {
    state = state.copyWith(
      status: RcHostStatus.listening,
      clearClient: true,
    );
  }

  void disconnectActiveSession() {
    _timer?.cancel();
    _timer = null;
    state = state.copyWith(
      status: RcHostStatus.listening,
      clearClient: true,
    );
  }

  void updateConfig(RcHostConfig newConfig) {
    state = state.copyWith(config: newConfig);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final rcHostProvider = NotifierProvider<RcHostNotifier, RcHostState>((ref) {
  return RcHostNotifier();
});

