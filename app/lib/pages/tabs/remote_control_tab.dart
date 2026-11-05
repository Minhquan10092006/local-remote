import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:refena_flutter/refena_flutter.dart';
import '../../model/remote_control/rc_device.dart';
import '../../model/remote_control/rc_session_state.dart';
import '../../provider/remote_control/rc_client_provider.dart';
import '../../provider/remote_control/rc_host_provider.dart';
import '../remote_control/rc_client_page.dart';
import '../remote_control/rc_host_page.dart';

class RemoteControlTab extends StatefulWidget {
  const RemoteControlTab({super.key});

  @override
  State<RemoteControlTab> createState() => _RemoteControlTabState();
}

class _RemoteControlTabState extends State<RemoteControlTab> with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  final TextEditingController _ipInputController = TextEditingController();
  final TextEditingController _pinInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    // Auto-scan on mobile when entering tab
    if (Platform.isAndroid || Platform.isIOS) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.notifier(rcClientProvider).scanDevices();
      });
    } else {
      // Auto-start server on desktop host
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.notifier(rcHostProvider).startListening();
      });
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _ipInputController.dispose();
    _pinInputController.dispose();
    super.dispose();
  }

  void _connectToDevice(BuildContext context, RcDevice device, {String? pin}) async {
    final clientNotifier = context.notifier(rcClientProvider);
    final success = await clientNotifier.connect(device, pin: pin);
    if (success && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RcClientPage(device: device),
        ),
      );
    } else if (mounted) {
      final err = context.read(rcClientProvider).errorMessage ?? 'Không thể kết nối tới máy tính';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  void _connectDirectFromInputs() {
    final ip = _ipInputController.text.trim();
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập địa chỉ IP của máy tính')),
      );
      return;
    }

    final pin = _pinInputController.text.trim();
    final device = RcDevice(
      id: 'direct-$ip',
      alias: 'Máy tính ($ip)',
      ip: ip,
      port: 53317,
      requiresPin: pin.isNotEmpty,
    );

    _connectToDevice(context, device, pin: pin.isNotEmpty ? pin : null);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = d.inHours;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    return isDesktop ? _buildDesktopHostView(context) : _buildMobileClientView(context);
  }

  /// -------------------------------------------------------------
  /// 💻 GIAO DIỆN DÀNH CHO MÁY TÍNH (HOST SERVER)
  /// -------------------------------------------------------------
  Widget _buildDesktopHostView(BuildContext context) {
    final theme = Theme.of(context);
    final hostState = context.watch(rcHostProvider);
    final hostNotifier = context.notifier(rcHostProvider);

    final isHostListening = hostState.status != RcHostStatus.idle;
    final isBeingControlled = hostState.status == RcHostStatus.activeSession;

    if (isBeingControlled) {
      if (!_rotationController.isAnimating) _rotationController.repeat();
    } else {
      if (_rotationController.isAnimating) {
        _rotationController.stop();
        _rotationController.reset();
      }
    }

    final displayIp = hostState.localIps.isNotEmpty ? hostState.localIps.first : '127.0.0.1';

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.desktop_windows),
            SizedBox(width: 8),
            Text('Máy chủ điều khiển (Host Server)'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              children: [
                // Thẻ điều khiển máy chủ
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        RotationTransition(
                          turns: _rotationController,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: isBeingControlled
                                  ? Colors.red.withOpacity(0.12)
                                  : isHostListening
                                      ? theme.colorScheme.primaryContainer
                                      : theme.colorScheme.surfaceVariant,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.devices_other,
                              size: 44,
                              color: isBeingControlled
                                  ? Colors.redAccent
                                  : isHostListening
                                      ? theme.colorScheme.primary
                                      : Colors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Máy chủ nhận điều khiển từ xa',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Chip(
                          avatar: Icon(
                            isHostListening ? Icons.check_circle : Icons.pause_circle_outline,
                            size: 16,
                            color: isHostListening ? Colors.green : Colors.grey,
                          ),
                          label: Text(
                            isHostListening ? 'Máy chủ: Đang bật (Sẵn sàng nhận)' : 'Máy chủ: Đang tắt',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: isHostListening
                              ? Colors.green.withOpacity(0.12)
                              : theme.colorScheme.surfaceVariant,
                        ),
                        const SizedBox(height: 20),

                        // Khung thông tin IP để nhập vào điện thoại
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.colorScheme.outlineVariant),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '📍 Địa chỉ IP của máy tính này:',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SelectableText(
                                    displayIp,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 20),
                                    tooltip: 'Sao chép IP',
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: displayIp));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Đã sao chép địa chỉ IP')),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              Text(
                                'Cổng: ${hostState.config.port} • Mở điện thoại và nhập IP trên để kết nối',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                backgroundColor: isHostListening ? Colors.redAccent : theme.colorScheme.primary,
                              ),
                              icon: Icon(isHostListening ? Icons.stop : Icons.play_arrow),
                              label: Text(
                                isHostListening ? 'Tắt nhận điều khiển' : 'Bật nhận điều khiển',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () {
                                if (isHostListening) {
                                  hostNotifier.stopListening();
                                } else {
                                  hostNotifier.startListening();
                                }
                              },
                            ),
                            const SizedBox(width: 14),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.settings_outlined),
                              label: const Text('Cài đặt PIN & FPS'),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const RcHostPage()),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Banner đỏ cảnh báo khi bị điều khiển
          if (isBeingControlled)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: Colors.red.shade100,
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đang bị điều khiển bởi: ${hostState.clientAlias ?? "Điện thoại từ xa"}',
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          'Thời gian: ${_formatDuration(hostState.sessionDuration)}',
                          style: TextStyle(color: Colors.red.shade900, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: hostNotifier.disconnectActiveSession,
                    child: const Text('Ngắt kết nối'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// -------------------------------------------------------------
  /// 📱 GIAO DIỆN DÀNH CHO ĐIỆN THOẠI (REMOTE CLIENT)
  /// -------------------------------------------------------------
  Widget _buildMobileClientView(BuildContext context) {
    final theme = Theme.of(context);
    final clientState = context.watch(rcClientProvider);
    final clientNotifier = context.notifier(rcClientProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.phone_android),
            SizedBox(width: 8),
            Text('Điều khiển máy tính từ xa'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Quét lại WiFi',
            onPressed: clientNotifier.scanDevices,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Thẻ 1: KẾT NỐI TRỰC TIẾP QUA IP MÁY TÍNH
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.link, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Kết nối nhanh qua IP máy tính',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _ipInputController,
                    keyboardType: TextInputType.datetime,
                    decoration: InputDecoration(
                      labelText: 'Địa chỉ IP máy tính',
                      hintText: 'Ví dụ: 192.168.1.105',
                      prefixIcon: const Icon(Icons.computer),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      helperText: 'Xem địa chỉ IP hiển thị trên màn hình ứng dụng máy tính',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pinInputController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Mã PIN (nếu máy tính cài đặt)',
                      hintText: 'Để trống nếu không cài PIN',
                      prefixIcon: const Icon(Icons.pin),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text(
                        'KẾT NỐI ĐIỀU KHIỂN NGAY',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _connectDirectFromInputs,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Thẻ 2: MÁY TÍNH TÌM THẤY TRONG MẠNG WIFI
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Máy tính tìm thấy trong mạng WiFi',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (clientState.status == RcClientStatus.discovering)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (clientState.discoveredDevices.isEmpty)
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Column(
                  children: [
                    Icon(Icons.wifi_find, size: 40, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    const Text(
                      'Chưa tự động dò thấy máy tính nào.\nHãy nhập IP máy tính vào ô phía trên để kết nối trực tiếp!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Quét lại mạng WiFi'),
                      onPressed: clientNotifier.scanDevices,
                    ),
                  ],
                ),
              ),
            )
          else
            ...clientState.discoveredDevices.map((dev) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    child: Icon(Icons.laptop, color: theme.colorScheme.primary),
                  ),
                  title: Text(dev.alias, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${dev.ip}:${dev.port} • ${dev.os}'),
                  trailing: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _connectToDevice(context, dev),
                    child: const Text('Kết nối'),
                  ),
                ),
              );
            }),

          const SizedBox(height: 16),

          // Thẻ 3: HƯỚNG DẪN CỬ CHỈ
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('💡 Hướng dẫn điều khiển khi vào màn hình:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  SizedBox(height: 6),
                  Text('• 1 ngón di trên bàn rê: Di chuột máy tính\n• 1 ngón chạm nhẹ: Click chuột trái\n• 2 ngón chạm nhẹ: Click chuột phải (Menu)\n• 2 ngón vuốt lên/xuống: Cuộn trang web, tài liệu\n• Chạm trực tiếp lên màn hình: Click vào vị trí đó', style: TextStyle(fontSize: 12, height: 1.4)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
