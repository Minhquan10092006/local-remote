import 'package:flutter/material.dart';
import '../../../model/remote_control/rc_client_message.dart';

class TouchPadWidget extends StatefulWidget {
  final Function(RcClientMessage) onSendInput;

  const TouchPadWidget({
    super.key,
    required this.onSendInput,
  });

  @override
  State<TouchPadWidget> createState() => _TouchPadWidgetState();
}

class _TouchPadWidgetState extends State<TouchPadWidget> {
  int _activePointers = 0;
  Offset? _lastPosition;
  DateTime _lastTapTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool _movedDuringGesture = false;

  void _handlePointerDown(PointerDownEvent event) {
    setState(() {
      _activePointers++;
      _lastPosition = event.position;
      _movedDuringGesture = false;
    });
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_lastPosition == null) {
      _lastPosition = event.position;
      return;
    }

    final dx = event.position.dx - _lastPosition!.dx;
    final dy = event.position.dy - _lastPosition!.dy;

    if (dx.abs() > 1.5 || dy.abs() > 1.5) {
      _movedDuringGesture = true;
    }

    if (_activePointers == 1) {
      // 1-finger move = relative mouse move (sensitivity multiplier 1.2)
      widget.onSendInput(RcMouseMove(
        dx: dx * 1.2,
        dy: dy * 1.2,
      ));
    } else if (_activePointers >= 2) {
      // 2-finger move = mouse scroll
      widget.onSendInput(RcMouseScroll(
        dx: dx * 0.8,
        dy: dy * 2.5,
      ));
    }

    _lastPosition = event.position;
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (!_movedDuringGesture) {
      final now = DateTime.now();
      if (_activePointers == 1) {
        // 1 finger tap = Left Click
        widget.onSendInput(const RcMouseButton(
          button: MouseButtonType.Left,
          pressed: true,
        ));
        Future.delayed(const Duration(milliseconds: 30), () {
          widget.onSendInput(const RcMouseButton(
            button: MouseButtonType.Left,
            pressed: false,
          ));
        });
      } else if (_activePointers == 2) {
        // 2 fingers tap = Right Click
        widget.onSendInput(const RcMouseButton(
          button: MouseButtonType.Right,
          pressed: true,
        ));
        Future.delayed(const Duration(milliseconds: 30), () {
          widget.onSendInput(const RcMouseButton(
            button: MouseButtonType.Right,
            pressed: false,
          ));
        });
      }
      _lastTapTime = now;
    }

    setState(() {
      _activePointers = (_activePointers - 1).clamp(0, 10);
      if (_activePointers == 0) {
        _lastPosition = null;
        _movedDuringGesture = false;
      }
    });
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    setState(() {
      _activePointers = 0;
      _lastPosition = null;
      _movedDuringGesture = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withOpacity(0.6),
            width: 1.5,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.touch_app_outlined,
                  size: 38,
                  color: theme.colorScheme.primary.withOpacity(0.4),
                ),
                const SizedBox(height: 8),
                Text(
                  'VÙNG VIRTUAL TRACKPAD',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '1 ngón di: di chuột  •  1 ngón chạm: click trái\n2 ngón chạm: click phải  •  2 ngón vuốt: cuộn',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.55),
                  ),
                ),
              ],
            ),
            if (_activePointers > 0)
              Positioned(
                top: 10,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$_activePointers ngón',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

