import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:refena_flutter/refena_flutter.dart';
import '../../model/remote_control/rc_client_message.dart';
import '../../model/remote_control/rc_device.dart';
import '../../provider/remote_control/rc_client_provider.dart';
import 'widget/keyboard_toolbar.dart';
import 'widget/touch_pad.dart';

class RcClientPage extends StatefulWidget {
  final RcDevice device;

  const RcClientPage({super.key, required this.device});

  @override
  State<RcClientPage> createState() => _RcClientPageState();
}

class _RcClientPageState extends State<RcClientPage> {
  bool _isFullscreen = false;
  bool _isDirectTouch = false;
  bool _isStreaming = true;
  Uint8List? _currentFrame;
  int _fpsCount = 0;
  DateTime _lastFpsTime = DateTime.now();
  int _currentFps = 0;
  HttpClient? _streamClient;

  @override
  void initState() {
    super.initState();
    _startStreamLoop();
  }

  void _startStreamLoop() async {
    _streamClient = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    while (mounted && _isStreaming) {
      final start = DateTime.now();
      try {
        final uri = Uri.parse('http://${widget.device.ip}:${widget.device.port}/screen/frame?t=${start.millisecondsSinceEpoch}');
        final req = await _streamClient!.getUrl(uri);
        final resp = await req.close();
        if (resp.statusCode == 200 && mounted) {
          final bytes = await resp.fold<List<int>>([], (acc, chunk) => acc..addAll(chunk));
          if (mounted && bytes.isNotEmpty) {
            setState(() {
              _currentFrame = Uint8List.fromList(bytes);
              _fpsCount++;
            });
          }
        }
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 60));
      }

      final now = DateTime.now();
      if (now.difference(_lastFpsTime).inSeconds >= 1) {
        if (mounted) {
          setState(() {
            _currentFps = _fpsCount;
            _fpsCount = 0;
            _lastFpsTime = now;
          });
        }
      }

      final elapsed = DateTime.now().difference(start).inMilliseconds;
      final waitMs = 33 - elapsed;
      if (waitMs > 0) {
        await Future.delayed(Duration(milliseconds: waitMs));
      }
    }
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
      if (_isFullscreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    });
  }

  void _handleScreenTapDown(TapDownDetails details, Size viewportSize) {
    if (!_isDirectTouch) return;
    final normX = (details.localPosition.dx / viewportSize.width).clamp(0.0, 1.0);
    final normY = (details.localPosition.dy / viewportSize.height).clamp(0.0, 1.0);

    final clientNotifier = context.notifier(rcClientProvider);
    clientNotifier.sendInput(RcMouseAbsolute(x: normX, y: normY));
    clientNotifier.sendInput(const RcMouseButton(button: MouseButtonType.Left, pressed: true));
    Future.delayed(const Duration(milliseconds: 30), () {
      clientNotifier.sendInput(const RcMouseButton(button: MouseButtonType.Left, pressed: false));
    });
  }

  void _handleScreenPanUpdate(DragUpdateDetails details, Size viewportSize) {
    if (!_isDirectTouch) return;
    final normX = (details.localPosition.dx / viewportSize.width).clamp(0.0, 1.0);
    final normY = (details.localPosition.dy / viewportSize.height).clamp(0.0, 1.0);

    final clientNotifier = context.notifier(rcClientProvider);
    clientNotifier.sendInput(RcMouseAbsolute(x: normX, y: normY));
  }

  @override
  void dispose() {
    _isStreaming = false;
    _streamClient?.close(force: true);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vm = context.watch(rcClientProvider);
    final clientNotifier = context.notifier(rcClientProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _isFullscreen
          ? null
          : AppBar(
              backgroundColor: theme.colorScheme.surface,
              elevation: 1,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  clientNotifier.disconnect();
                  Navigator.of(context).pop();
                },
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.device.alias,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.device.ip} • ${vm.latencyMs}ms • $_currentFps FPS',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                // Direct touch vs trackpad mode toggle
                IconButton(
                  tooltip: _isDirectTouch ? 'Chế độ cảm ứng trực tiếp' : 'Chế độ Trackpad',
                  icon: Icon(_isDirectTouch ? Icons.touch_app : Icons.mouse),
                  onPressed: () => setState(() => _isDirectTouch = !_isDirectTouch),
                ),
                // Audio toggle
                IconButton(
                  tooltip: vm.isAudioEnabled ? 'Tắt âm thanh' : 'Bật âm thanh',
                  icon: Icon(vm.isAudioEnabled ? Icons.volume_up : Icons.volume_off),
                  onPressed: clientNotifier.toggleAudio,
                ),
                // Fullscreen toggle
                IconButton(
                  tooltip: 'Toàn màn hình',
                  icon: const Icon(Icons.fullscreen),
                  onPressed: _toggleFullscreen,
                ),
                // Disconnect
                IconButton(
                  tooltip: 'Ngắt kết nối',
                  icon: const Icon(Icons.close, color: Colors.redAccent),
                  onPressed: () {
                    clientNotifier.disconnect();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
      body: SafeArea(
        top: !_isFullscreen,
        bottom: !_isFullscreen,
        child: Column(
          children: [
            // Stream Viewport (16:9 aspect ratio)
            Expanded(
              flex: 5,
              child: Container(
                color: Colors.black,
                width: double.infinity,
                alignment: Alignment.center,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final vpSize = Size(constraints.maxWidth, constraints.maxHeight);
                    return GestureDetector(
                      onTapDown: (details) => _handleScreenTapDown(details, vpSize),
                      onPanUpdate: (details) => _handleScreenPanUpdate(details, vpSize),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF151515),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            alignment: Alignment.center,
                            children: [
                              // Live Screen Stream Frame
                              if (_currentFrame != null)
                                Image.memory(
                                  _currentFrame!,
                                  gaplessPlayback: true,
                                  fit: BoxFit.contain,
                                )
                              else
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(color: theme.colorScheme.primary),
                                    const SizedBox(height: 14),
                                    Text(
                                      'Đang kết nối tới máy tính (${widget.device.ip})...',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Đang nhận hình ảnh màn hình trực tiếp',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.4),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),

                              // FPS tag overlay
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '$_currentFps FPS',
                                    style: const TextStyle(
                                      color: Colors.greenAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),

                              if (_isFullscreen)
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: IconButton(
                                    icon: const Icon(Icons.fullscreen_exit, color: Colors.white70),
                                    onPressed: _toggleFullscreen,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Keyboard Toolbar
            KeyboardToolbarWidget(
              activeModifiers: vm.activeModifiers,
              onToggleModifier: clientNotifier.toggleModifier,
              onSendInput: clientNotifier.sendInput,
              onClearModifiers: clientNotifier.clearModifiers,
            ),

            // Virtual Trackpad
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: TouchPadWidget(
                  onSendInput: clientNotifier.sendInput,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
