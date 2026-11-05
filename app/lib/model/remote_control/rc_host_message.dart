import 'dart:convert';
import 'rc_client_message.dart';

abstract class RcHostMessage {
  const RcHostMessage();

  factory RcHostMessage.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    switch (type) {
      case 'ScreenResolution':
        return RcScreenResolution(
          width: json['width'] as int,
          height: json['height'] as int,
        );
      case 'ClipboardUpdate':
        return RcHostClipboardUpdate(
          content: json['content'] as String,
          format: json['format'] == 'Text' ? ClipboardFormat.Text : ClipboardFormat.Text,
        );
      case 'SessionStatus':
        return RcSessionStatus(
          fps: json['fps'] as int,
          bitrateKbps: json['bitrateKbps'] as int,
          clientAlias: json['clientAlias'] as String,
        );
      case 'AuthResponse':
        return RcAuthResponse(
          success: json['success'] as bool,
          requiresApproval: json['requires_approval'] as bool? ?? false,
          errorMessage: json['error_message'] as String?,
        );
      case 'Disconnected':
        return RcDisconnected(
          reason: json['reason'] as String? ?? 'Disconnected',
        );
      default:
        return RcUnknownMessage(json);
    }
  }

  static RcHostMessage? parse(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
      return RcHostMessage.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }
}

class RcScreenResolution extends RcHostMessage {
  final int width;
  final int height;

  const RcScreenResolution({required this.width, required this.height});
}

class RcHostClipboardUpdate extends RcHostMessage {
  final String content;
  final ClipboardFormat format;

  const RcHostClipboardUpdate({required this.content, required this.format});
}

class RcSessionStatus extends RcHostMessage {
  final int fps;
  final int bitrateKbps;
  final String clientAlias;

  const RcSessionStatus({
    required this.fps,
    required this.bitrateKbps,
    required this.clientAlias,
  });
}

class RcAuthResponse extends RcHostMessage {
  final bool success;
  final bool requiresApproval;
  final String? errorMessage;

  const RcAuthResponse({
    required this.success,
    required this.requiresApproval,
    this.errorMessage,
  });
}

class RcDisconnected extends RcHostMessage {
  final String reason;

  const RcDisconnected({required this.reason});
}

class RcUnknownMessage extends RcHostMessage {
  final Map<String, dynamic> raw;

  const RcUnknownMessage(this.raw);
}

