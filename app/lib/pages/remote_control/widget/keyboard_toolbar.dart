import 'package:flutter/material.dart';
import '../../../model/remote_control/rc_client_message.dart';

class KeyboardToolbarWidget extends StatefulWidget {
  final Set<String> activeModifiers;
  final Function(String) onToggleModifier;
  final Function(RcClientMessage) onSendInput;
  final VoidCallback onClearModifiers;

  const KeyboardToolbarWidget({
    super.key,
    required this.activeModifiers,
    required this.onToggleModifier,
    required this.onSendInput,
    required this.onClearModifiers,
  });

  @override
  State<KeyboardToolbarWidget> createState() => _KeyboardToolbarWidgetState();
}

class _KeyboardToolbarWidgetState extends State<KeyboardToolbarWidget> {
  final TextEditingController _textController = TextEditingController();
  bool _showTextInput = false;

  void _sendKeyPress(String key) {
    widget.onSendInput(RcKeyEvent(
      key: key,
      pressed: true,
      modifiers: widget.activeModifiers.toList(),
    ));
    Future.delayed(const Duration(milliseconds: 40), () {
      widget.onSendInput(RcKeyEvent(
        key: key,
        pressed: false,
        modifiers: widget.activeModifiers.toList(),
      ));
    });
  }

  void _submitText(String text) {
    if (text.isEmpty) return;
    for (final char in text.characters) {
      _sendKeyPress(char);
    }
    _textController.clear();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final specialKeys = [
      {'label': 'Tab', 'key': 'tab'},
      {'label': 'Esc', 'key': 'escape'},
      {'label': 'Enter', 'key': 'enter'},
      {'label': '⌫', 'key': 'backspace'},
      {'label': 'Del', 'key': 'delete'},
      {'label': 'Space', 'key': 'space'},
      {'label': '←', 'key': 'left'},
      {'label': '↑', 'key': 'up'},
      {'label': '↓', 'key': 'down'},
      {'label': '→', 'key': 'right'},
      {'label': 'F1', 'key': 'f1'},
      {'label': 'F2', 'key': 'f2'},
      {'label': 'F5', 'key': 'f5'},
      {'label': 'F11', 'key': 'f11'},
      {'label': 'F12', 'key': 'f12'},
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showTextInput)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Nhập văn bản gửi lên máy tính...',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onSubmitted: _submitText,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _submitText(_textController.text),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _showTextInput = false),
                ),
              ],
            ),
          ),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
              bottom: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
            ),
          ),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Modifiers
              _buildModifierChip('Ctrl', 'ctrl', theme),
              _buildModifierChip('Alt', 'alt', theme),
              _buildModifierChip('Shift', 'shift', theme),
              _buildModifierChip('Win', 'win', theme),
              const VerticalDivider(width: 12, indent: 6, endIndent: 6),

              // Text summon button
              ActionChip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.keyboard, size: 16),
                label: const Text('Gõ chữ'),
                onPressed: () {
                  setState(() => _showTextInput = !_showTextInput);
                },
              ),
              const SizedBox(width: 6),

              // Special keys
              ...specialKeys.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ActionChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      item['label']!,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    onPressed: () => _sendKeyPress(item['key']!),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModifierChip(String label, String key, ThemeData theme) {
    final isActive = widget.activeModifiers.contains(key);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: FilterChip(
        visualDensity: VisualDensity.compact,
        selected: isActive,
        selectedColor: theme.colorScheme.primaryContainer,
        label: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: isActive ? theme.colorScheme.onPrimaryContainer : null,
          ),
        ),
        onSelected: (_) => widget.onToggleModifier(key),
      ),
    );
  }
}

