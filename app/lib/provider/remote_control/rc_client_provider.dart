import 'dart:async';
import 'package:refena_flutter/refena_flutter.dart';
import '../../model/remote_control/rc_client_message.dart';
import '../../model/remote_control/rc_device.dart';
import '../../model/remote_control/rc_session_state.dart';

class RcClientState {
  final RcClientStatus status;
  final List<RcDevice> discoveredDevices;
  final RcDevice? connectedDevice;
  final String? errorMessage;
  final int latencyMs;
  final bool isAudioEnabled;
  final Set<String> activeModifiers;

  const RcClientState({
    this.status = RcClientStatus.disconnected,
    this.discoveredDevices = const [],
    this.connectedDevice,
    this.errorMessage,
    this.latencyMs = 0,
    this.isAudioEnabled = true,
    this.activeModifiers = const {},
  });

  RcClientState copyWith({
    RcClientStatus? status,
    List<RcDevice>? discoveredDevices,
    RcDevice? connectedDevice,
    bool clearConnectedDevice = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    int? latencyMs,
    bool? isAudioEnabled,
    Set<String>? activeModifiers,
  }) {
    return RcClientState(
      status: status ?? this.status,
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      connectedDevice: clearConnectedDevice ? null : (connectedDevice ?? this.connectedDevice),
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      latencyMs: latencyMs ?? this.latencyMs,
      isAudioEnabled: isAudioEnabled ?? this.isAudioEnabled,
      activeModifiers: activeModifiers ?? this.activeModifiers,
    );
  }
}

class RcClientNotifier extends Notifier<RcClientState> {
  Timer? _mockPingTimer;

  @override
  RcClientState init() {
    return const RcClientState(
      discoveredDevices: [
        RcDevice(
          id: 'pc-1',
          alias: 'Laptop-Office',
          ip: '192.168.100.105',
          port: 53317,
          requiresPin: false,
        ),
      ],
    );
  }

  void scanDevices() {
    state = state.copyWith(status: RcClientStatus.discovering);
    // Simulate smart LAN network scan discovery
    Future.delayed(const Duration(milliseconds: 600), () {
      final currentList = List<RcDevice>.from(state.discoveredDevices);
      if (!currentList.any((d) => d.ip == '192.168.100.105')) {
        currentList.add(
          const RcDevice(
            id: 'pc-1',
            alias: 'Laptop-Office',
            ip: '192.168.100.105',
            port: 53317,
          ),
        );
      }
      state = state.copyWith(
        status: state.status == RcClientStatus.discovering
            ? RcClientStatus.disconnected
            : state.status,
        discoveredDevices: currentList,
      );
    });
  }

  Future<bool> connect(RcDevice device, {String? pin}) async {
    state = state.copyWith(
      status: RcClientStatus.connecting,
      connectedDevice: device,
      clearErrorMessage: true,
    );

    // Handshake delay simulation
    await Future.delayed(const Duration(milliseconds: 500));

    state = state.copyWith(
      status: RcClientStatus.connected,
      latencyMs: 14,
    );

    _mockPingTimer?.cancel();
    _mockPingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (state.status == RcClientStatus.connected) {
        state = state.copyWith(latencyMs: 12 + (DateTime.now().millisecond % 8));
      }
    });

    return true;
  }

  void disconnect() {
    _mockPingTimer?.cancel();
    _mockPingTimer = null;
    state = state.copyWith(
      status: RcClientStatus.disconnected,
      clearConnectedDevice: true,
      activeModifiers: {},
    );
  }

  void toggleAudio() {
    state = state.copyWith(isAudioEnabled: !state.isAudioEnabled);
  }

  void toggleModifier(String key) {
    final updated = Set<String>.from(state.activeModifiers);
    if (updated.contains(key)) {
      updated.remove(key);
      sendInput(RcKeyEvent(key: key, pressed: false));
    } else {
      updated.add(key);
      sendInput(RcKeyEvent(key: key, pressed: true));
    }
    state = state.copyWith(activeModifiers: updated);
  }

  void clearModifiers() {
    for (final mod in state.activeModifiers) {
      sendInput(RcKeyEvent(key: mod, pressed: false));
    }
    state = state.copyWith(activeModifiers: {});
  }

  void sendInput(RcClientMessage message) {
    // Dispatches message to WebRTC DataChannel
    // message.serialize();
  }

  @override
  void dispose() {
    _mockPingTimer?.cancel();
    super.dispose();
  }
}

final rcClientProvider = NotifierProvider<RcClientNotifier, RcClientState>((ref) {
  return RcClientNotifier();
});

