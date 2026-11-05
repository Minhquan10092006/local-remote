import 'package:flutter/material.dart';
import 'package:refena_flutter/refena_flutter.dart';
import '../../model/remote_control/rc_host_config.dart';
import '../../provider/remote_control/rc_host_provider.dart';

class RcHostPage extends StatefulWidget {
  const RcHostPage({super.key});

  @override
  State<RcHostPage> createState() => _RcHostPageState();
}

class _RcHostPageState extends State<RcHostPage> {
  late bool _requirePin;
  late TextEditingController _pinController;
  late int _targetFps;
  late bool _requireApproval;

  @override
  void initState() {
    super.initState();
    final config = ref.read(rcHostProvider).config;
    _requirePin = config.pin != null && config.pin!.isNotEmpty;
    _pinController = TextEditingController(text: config.pin ?? '');
    _targetFps = config.targetFps;
    _requireApproval = config.requireApproval;
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    final newPin = _requirePin ? _pinController.text.trim() : null;
    if (_requirePin && (newPin == null || newPin.length < 4 || newPin.length > 8)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mã PIN phải từ 4 đến 8 ký tự số')),
      );
      return;
    }

    final currentConfig = ref.read(rcHostProvider).config;
    final updatedConfig = currentConfig.copyWith(
      pin: newPin,
      targetFps: _targetFps,
      requireApproval: _requireApproval,
    );

    ref.notifier(rcHostProvider).updateConfig(updatedConfig);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã lưu cấu hình máy chủ điều khiển')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt Máy chủ (Host)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveSettings,
            tooltip: 'Lưu cài đặt',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section: PIN Security
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Icon(Icons.lock_outline, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bảo mật mã PIN',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Yêu cầu nhập đúng PIN để kết nối',
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _requirePin,
                      onChanged: (val) {
                        setState(() => _requirePin = val);
                      },
                    ),
                  ],
                ),
                if (_requirePin) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    maxLength: 8,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Mã PIN (4 - 8 chữ số)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.key),
                      counterText: '',
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section: Frame Rate (FPS)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Icon(Icons.speed, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    const Text(
                      'Tốc độ khung hình (FPS)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 30, label: Text('30 FPS')),
                    ButtonSegment(value: 50, label: Text('50 FPS')),
                    ButtonSegment(value: 60, label: Text('60 FPS')),
                  ],
                  selected: {_targetFps},
                  onSelectionChanged: (val) {
                    setState(() => _targetFps = val.first);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section: Manual Approval
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: SwitchListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              secondary: Icon(Icons.verified_user_outlined, color: theme.colorScheme.primary),
              title: const Text('Phê duyệt trước khi cho phép kết nối'),
              subtitle: const Text('Hiện hộp thoại xác nhận trên màn hình Host'),
              value: _requireApproval,
              onChanged: (val) => setState(() => _requireApproval = val),
            ),
          ),
        ],
      ),
    );
  }
}

