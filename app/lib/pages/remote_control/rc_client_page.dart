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

  void _handleScreenTapDown(TapDownDetails details, Size viewportSize, WidgetRef ref) {
    if (!_isDirectTouch) return;
    // Normalized absolute mouse coordinate [0.0, 1.0]
    final normX = (details.localPosition.dx / viewportSize.width).clamp(0.0, 1.0);
    final normY = (details.localPosition.dy / viewportSize.height).clamp(0.0, 1.0);

    final clientNotifier = ref.notifier(rcClientProvider);
    clientNotifier.sendInput(RcMouseAbsolute(x: normX, y: normY));
    clientNotifier.sendInput(const RcMouseButton(button: MouseButtonType.Left, pressed: true));
    Future.delayed(const Duration(milliseconds: 30), () {
      clientNotifier.sendInput(const RcMouseButton(button: MouseButtonType.Left, pressed: false));
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ViewModelBuilder(
      provider: rcClientProvider,
      builder: (context, vm, ref) {
        final clientNotifier = ref.notifier(rcClientProvider);

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
                            '${widget.device.ip} • ${vm.latencyMs}ms',
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
                // Stream Viewport (16:9 aspect ratio or flexible)
                Expanded(
                  flex: 5,
                  child: Container(
                    color: Colors.black,
                    width: double.infinity,
                    alignment: Alignment.center,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return GestureDetector(
                          onTapDown: (details) => _handleScreenTapDown(
                            details,
                            Size(constraints.maxWidth, constraints.maxHeight),
                            ref,
                          ),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1E1E),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Live Stream surface / placeholder
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.desktop_windows,
                                        size: 64,
                                        color: Colors.white.withOpacity(0.2),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Khung hình máy tính truyền về (16:9)',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.5),
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Độ phân giải: 1920x1080 @ 60 FPS',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.3),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
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
      },
    );
  }
}

