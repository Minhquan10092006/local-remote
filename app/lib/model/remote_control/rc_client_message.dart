import 'dart:convert';

enum MouseButtonType {
  Left,
  Right,
  Middle,
}

enum ClipboardFormat {
  Text,
}

abstract class RcClientMessage {
  const RcClientMessage();

  Map<String, dynamic> toJson();

  String serialize() => jsonEncode(toJson());
}

class RcMouseMove extends RcClientMessage {
  final double dx;
  final double dy;

  const RcMouseMove({required this.dx, required this.dy});

  @override
  Map<String, dynamic> toJson() => {
    'type': 'MouseMove',
    'dx': dx.clamp(-2000.0, 2000.0),
    'dy': dy.clamp(-2000.0, 2000.0),
  };
}

class RcMouseAbsolute extends RcClientMessage {
  final double x;
  final double y;

  const RcMouseAbsolute({required this.x, required this.y});

  @override
  Map<String, dynamic> toJson() => {
    'type': 'MouseAbsolute',
    'x': x.clamp(0.0, 1.0),
    'y': y.clamp(0.0, 1.0),
  };
}

class RcMouseButton extends RcClientMessage {
  final MouseButtonType button;
  final bool pressed;

  const RcMouseButton({required this.button, required this.pressed});

  @override
  Map<String, dynamic> toJson() => {
    'type': 'MouseButton',
    'button': button.name,
    'pressed': pressed,
  };
}

class RcMouseScroll extends RcClientMessage {
  final double dx;
  final double dy;

  const RcMouseScroll({required this.dx, required this.dy});

  @override
  Map<String, dynamic> toJson() => {
    'type': 'MouseScroll',
    'dx': dx.clamp(-500.0, 500.0),
    'dy': dy.clamp(-500.0, 500.0),
  };
}

class RcKeyEvent extends RcClientMessage {
  final String key;
  final bool pressed;
  final List<String> modifiers;

  const RcKeyEvent({
    required this.key,
    required this.pressed,
    this.modifiers = const [],
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'KeyEvent',
    'key': key,
    'pressed': pressed,
    'modifiers': modifiers,
  };
}

class RcClipboardUpdate extends RcClientMessage {
  final String content;
  final ClipboardFormat format;

  const RcClipboardUpdate({
    required this.content,
    this.format = ClipboardFormat.Text,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'ClipboardUpdate',
    'content': content,
    'format': format.name,
  };
}

class RcAuthRequest extends RcClientMessage {
  final String? pin;
  final String clientName;

  const RcAuthRequest({this.pin, required this.clientName});

  @override
  Map<String, dynamic> toJson() => {
    'type': 'AuthRequest',
    'pin': pin,
    'client_name': clientName,
  };
}

