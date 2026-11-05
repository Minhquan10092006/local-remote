import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:refena_flutter/refena_flutter.dart';
import '../../model/remote_control/rc_host_config.dart';
import '../../model/remote_control/rc_session_state.dart';
import 'win32_screen_capturer.dart';

class RcHostState {
  final RcHostStatus status;
  final RcHostConfig config;
  final String? clientAlias;
  final DateTime? connectedSince;
  final Duration sessionDuration;
  final List<String> localIps;

  const RcHostState({
    this.status = RcHostStatus.idle,
    this.config = const RcHostConfig(),
    this.clientAlias,
    this.connectedSince,
    this.sessionDuration = Duration.zero,
    this.localIps = const [],
  });

  RcHostState copyWith({
    RcHostStatus? status,
    RcHostConfig? config,
    String? clientAlias,
    bool clearClient = false,
    DateTime? connectedSince,
    Duration? sessionDuration,
    List<String>? localIps,
  }) {
    return RcHostState(
      status: status ?? this.status,
      config: config ?? this.config,
      clientAlias: clearClient ? null : (clientAlias ?? this.clientAlias),
      connectedSince: clearClient ? null : (connectedSince ?? this.connectedSince),
      sessionDuration: clearClient ? Duration.zero : (sessionDuration ?? this.sessionDuration),
      localIps: localIps ?? this.localIps,
    );
  }
}

class RcHostNotifier extends Notifier<RcHostState> {
  Timer? _timer;
  HttpServer? _server;
  Uint8List? _cachedFrame;
  Timer? _captureTimer;

  @override
  RcHostState init() {
    _refreshIps();
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      Future.microtask(() => startListening());
    }
    return const RcHostState();
  }

  Future<void> _refreshIps() async {
    final ips = <String>[];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.address.contains('.')) {
            ips.add(addr.address);
          }
        }
      }
    } catch (_) {}
    state = state.copyWith(localIps: ips);
  }

  Future<void> startListening() async {
    await _refreshIps();
    await _startHttpServer();
    state = state.copyWith(status: RcHostStatus.listening);
  }

  Future<void> _startHttpServer() async {
    try {
      await _server?.close(force: true);
      _server = await HttpServer.bind(InternetAddress.anyIPv4, state.config.port);
      _server!.listen(_handleHttpRequest);

      // Start frame capture loop (approx. 30 FPS)
      _captureTimer?.cancel();
      _captureTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
        if (state.status == RcHostStatus.activeSession || state.status == RcHostStatus.listening) {
          try {
            final frame = Win32ScreenCapturer.captureFrame();
            if (frame != null && frame.isNotEmpty) {
              _cachedFrame = frame;
            }
          } catch (_) {}
        }
      });
    } catch (e) {
      // Port may already be in use
    }
  }

  void _handleHttpRequest(HttpRequest request) async {
    // Add CORS headers for mobile clients
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    final path = request.uri.path;

    if (path == '/info' || path == '/status') {
      final data = {
        'name': Platform.localHostname,
        'platform': Platform.operatingSystem,
        'status': state.status.name,
        'requiresPin': state.config.pin != null && state.config.pin!.isNotEmpty,
        'fps': state.config.targetFps,
        'port': state.config.port,
      };
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(data));
      await request.response.close();
      return;
    }

    if (path == '/auth' && request.method == 'POST') {
      final body = await utf8.decodeStream(request);
      final json = jsonDecode(body) as Map<String, dynamic>;
      final clientPin = json['pin'] as String?;
      final clientName = json['client_name'] as String? ?? 'Android Device';

      if (state.config.pin != null && state.config.pin!.isNotEmpty) {
        if (clientPin != state.config.pin) {
          request.response.statusCode = HttpStatus.unauthorized;
          request.response.write(jsonEncode({'success': false, 'message': 'Sai mã PIN'}));
          await request.response.close();
          return;
        }
      }

      acceptClient(clientName);
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'success': true, 'message': 'Đã kết nối thành công'}));
      await request.response.close();
      return;
    }

    if (path == '/screen/frame') {
      // Serve current screen frame
      request.response.headers.add('Cache-Control', 'no-cache, no-store, must-revalidate');
      Uint8List? frame = _cachedFrame;
      if (frame == null || frame.isEmpty) {
        try {
          frame = Win32ScreenCapturer.captureFrame();
          if (frame != null && frame.isNotEmpty) {
            _cachedFrame = frame;
          }
        } catch (_) {}
      }

      request.response.headers.contentType = ContentType('image', 'bmp');
      if (frame != null && frame.isNotEmpty) {
        request.response.add(frame);
      } else {
        request.response.add(_generateFallbackBmp(320, 180));
      }
      await request.response.close();
      return;
    }

    if (path == '/input' && request.method == 'POST') {
      final body = await utf8.decodeStream(request);
      try {
        final json = jsonDecode(body) as Map<String, dynamic>;
        Win32ScreenCapturer.injectInput(json);
      } catch (_) {}
      request.response.statusCode = HttpStatus.ok;
      request.response.write('{"status": "ok"}');
      await request.response.close();
      return;
    }

    if (path == '/disconnect') {
      disconnectActiveSession();
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
  }

  Uint8List _generateFallbackBmp(int w, int h) {
    // Generates a valid 32-bit BMP placeholder image (teal with grid)
    final rowSize = ((w * 32 + 31) ~/ 32) * 4;
    final dataSize = rowSize * h;
    final fileSize = 54 + dataSize;
    final bytes = Uint8List(fileSize);
    final bd = ByteData.view(bytes.buffer);

    // BMP header
    bytes[0] = 0x42; // 'B'
    bytes[1] = 0x4D; // 'M'
    bd.setUint32(2, fileSize, Endian.little);
    bd.setUint32(10, 54, Endian.little); // Pixel offset

    // DIB header
    bd.setUint32(14, 40, Endian.little); // Header size
    bd.setInt32(18, w, Endian.little);
    bd.setInt32(22, h, Endian.little);
    bd.setUint16(26, 1, Endian.little); // Planes
    bd.setUint16(28, 32, Endian.little); // 32 bpp
    bd.setUint32(34, dataSize, Endian.little);

    // Fill with Teal desktop color (B=96, G=106, R=0)
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final offset = 54 + (y * rowSize) + (x * 4);
        final isGrid = (x % 30 == 0) || (y % 30 == 0);
        bytes[offset] = isGrid ? 120 : 96;     // Blue
        bytes[offset + 1] = isGrid ? 130 : 106; // Green
        bytes[offset + 2] = isGrid ? 20 : 0;    // Red
        bytes[offset + 3] = 255;                // Alpha
      }
    }
    return bytes;
  }

  void stopListening() {
    _timer?.cancel();
    _timer = null;
    _captureTimer?.cancel();
    _captureTimer = null;
    _server?.close(force: true);
    _server = null;
    state = state.copyWith(
      status: RcHostStatus.idle,
      clearClient: true,
    );
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
    _captureTimer?.cancel();
    _server?.close(force: true);
    super.dispose();
  }
}

final rcHostProvider = NotifierProvider<RcHostNotifier, RcHostState>((ref) {
  return RcHostNotifier();
});
