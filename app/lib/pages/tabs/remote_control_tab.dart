import 'dart:math' as math;
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _showDirectConnectDialog(BuildContext context) {
    final ipController = TextEditingController();
    final pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_link),
            SizedBox(width: 8),
            Text('Kết nối trực tiếp'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                labelText: 'Địa chỉ IP máy tính',
                hintText: 'ví dụ: 192.168.1.100',
                prefixIcon: Icon(Icons.computer),
              ),
              keyboardType: TextInputType.datetime,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pinController,
              decoration: const InputDecoration(
                labelText: 'Mã PIN (nếu có)',
                prefixIcon: Icon(Icons.pin),
              ),
              obscureText: true,
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              final ip = ipController.text.trim();
              if (ip.isEmpty) return;

              final device = RcDevice(
                id: 'direct-$ip',
                alias: 'Máy tính ($ip)',
                ip: ip,
                requiresPin: pinController.text.isNotEmpty,
              );

              Navigator.of(ctx).pop();
              _connectToDevice(context, device, pin: pinController.text.trim());
            },
            child: const Text('Kết nối'),
          ),
        ],
      ),
    );
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
    }
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
    final theme = Theme.of(context);
    final hostState = context.watch(rcHostProvider);
    final clientState = context.watch(rcClientProvider);
    final hostNotifier = context.notifier(rcHostProvider);
    final clientNotifier = context.notifier(rcClientProvider);

    final isHostListening = hostState.status != RcHostStatus.idle;
    final isBeingControlled = hostState.status == RcHostStatus.activeSession;

    if (isBeingControlled) {
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
    } else {
      if (_rotationController.isAnimating) {
        _rotationController.stop();
        _rotationController.reset();
      }
    }

    // Critical Lesson 8.1: Flatten widgets into children list of ListView
    // Never nest ColumnListView inside an unconstrained scrollable.
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.desktop_windows_outlined),
            SizedBox(width: 8),
            Text('Remote Desktop'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Quét lại mạng WiFi',
            onPressed: clientNotifier.scanDevices,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Kết nối trực tiếp bằng IP',
            onPressed: () => _showDirectConnectDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // 1. Host Control Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: theme.colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    child: Column(
                      children: [
                        RotationTransition(
                          turns: _rotationController,
                          child: Container(
                            width: 72,
                            height: 72,
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
                              size: 38,
                              color: isBeingControlled
                                  ? Colors.redAccent
                                  : isHostListening
                                      ? theme.colorScheme.primary
                                      : Colors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Remote Desktop Control',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            Chip(
                              avatar: Icon(
                                isHostListening ? Icons.check_circle : Icons.pause_circle_outline,
                                size: 16,
                                color: isHostListening ? Colors.green : Colors.grey,
                              ),
                              label: Text(
                                isHostListening ? 'Máy chủ: Đang bật' : 'Máy chủ: Đã tắt',
                                style: const TextStyle(fontSize: 12),
                              ),
                              backgroundColor: isHostListening
                                  ? Colors.green.withOpacity(0.1)
                                  : theme.colorScheme.surfaceVariant.withOpacity(0.4),
                            ),
                            if (isBeingControlled)
                              Chip(
                                avatar: const Icon(Icons.warning, size: 16, color: Colors.redAccent),
                                label: const Text(
                                  'Đang bị điều khiển',
                                  style: TextStyle(fontSize: 12, color: Colors.redAccent),
                                ),
                                backgroundColor: Colors.red.withOpacity(0.1),
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                backgroundColor: isHostListening
                                    ? Colors.redAccent
                                    : theme.colorScheme.primary,
                              ),
                              icon: Icon(isHostListening ? Icons.stop : Icons.play_arrow),
                              label: Text(isHostListening ? 'Tắt nhận' : 'Bật nhận'),
                              onPressed: () {
                                if (isHostListening) {
                                  hostNotifier.stopListening();
                                } else {
                                  hostNotifier.startListening();
                                }
                              },
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.settings_outlined),
                              label: const Text('Cài đặt'),
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
                const SizedBox(height: 20),

                // 2. Discovered Devices Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Máy tính trong mạng (Để điều khiển)',
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

                // 3. Discovered Devices List
                if (clientState.discoveredDevices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.wifi_tethering_off, size: 40, color: Colors.grey.withOpacity(0.5)),
                          const SizedBox(height: 8),
                          Text(
                            'Chưa phát hiện máy tính nào trong cùng WiFi.\nBấm nút "+" để kết nối trực tiếp qua IP.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
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
                        title: Text(
                          dev.alias,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
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
              ],
            ),
          ),

          // 4. Red Persistent Kill-Switch Warning Banner (Layer 5 Security)
          if (isBeingControlled)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                border: Border(
                  top: BorderSide(color: Colors.red.shade400, width: 1.5),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đang bị điều khiển bởi: ${hostState.clientAlias ?? "Thiết bị từ xa"}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Thời gian kết nối: ${_formatDuration(hostState.sessionDuration)}',
                          style: TextStyle(
                            color: Colors.red.shade900,
                            fontSize: 12,
                          ),
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
                    child: const Text('Ngắt'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

