use serde::{Deserialize, Serialize};

/// Maximum allowed payload size for clipboard updates (10 MB).
pub const MAX_CLIPBOARD_BYTES: usize = 10 * 1024 * 1024;

/// Clamping bounds for mouse movement and scrolling.
pub const MOUSE_MOVE_MAX_DELTA: f64 = 2000.0;
pub const MOUSE_SCROLL_MAX_DELTA: f64 = 500.0;

/// Mouse button identifiers.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum MouseButtonType {
    Left,
    Right,
    Middle,
}

/// Clipboard format options.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ClipboardFormat {
    Text,
}

/// Messages sent from the Client (Android/Controller) to the Host (PC).
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum RcClientMessage {
    /// Relative mouse move (e.g. trackpad swipe).
    MouseMove {
        dx: f64,
        dy: f64,
    },
    /// Normalized absolute mouse coordinates [0.0, 1.0].
    MouseAbsolute {
        x: f64,
        y: f64,
    },
    /// Mouse button press/release.
    MouseButton {
        button: MouseButtonType,
        pressed: bool,
    },
    /// Mouse wheel scroll event.
    MouseScroll {
        dx: f64,
        dy: f64,
    },
    /// Hardware/Virtual key event.
    KeyEvent {
        key: String,
        pressed: bool,
        #[serde(default)]
        modifiers: Vec<String>,
    },
    /// Clipboard content from client to host.
    ClipboardUpdate {
        content: String,
        format: ClipboardFormat,
    },
    /// Authentication handshake with PIN.
    AuthRequest {
        pin: Option<String>,
        client_name: String,
    },
}

impl RcClientMessage {
    /// Validates and sanitizes the client message against security constraints.
    pub fn sanitize(self) -> Option<Self> {
        match self {
            RcClientMessage::MouseMove { dx, dy } => {
                if dx.is_nan() || dy.is_nan() || dx.is_infinite() || dy.is_infinite() {
                    return None;
                }
                Some(RcClientMessage::MouseMove {
                    dx: dx.clamp(-MOUSE_MOVE_MAX_DELTA, MOUSE_MOVE_MAX_DELTA),
                    dy: dy.clamp(-MOUSE_MOVE_MAX_DELTA, MOUSE_MOVE_MAX_DELTA),
                })
            }
            RcClientMessage::MouseAbsolute { x, y } => {
                if x.is_nan() || y.is_nan() || x.is_infinite() || y.is_infinite() {
                    return None;
                }
                Some(RcClientMessage::MouseAbsolute {
                    x: x.clamp(0.0, 1.0),
                    y: y.clamp(0.0, 1.0),
                })
            }
            RcClientMessage::MouseScroll { dx, dy } => {
                if dx.is_nan() || dy.is_nan() || dx.is_infinite() || dy.is_infinite() {
                    return None;
                }
                Some(RcClientMessage::MouseScroll {
                    dx: dx.clamp(-MOUSE_SCROLL_MAX_DELTA, MOUSE_SCROLL_MAX_DELTA),
                    dy: dy.clamp(-MOUSE_SCROLL_MAX_DELTA, MOUSE_SCROLL_MAX_DELTA),
                })
            }
            RcClientMessage::ClipboardUpdate { content, format } => {
                if content.len() > MAX_CLIPBOARD_BYTES {
                    return None;
                }
                Some(RcClientMessage::ClipboardUpdate { content, format })
            }
            msg => Some(msg),
        }
    }
}

/// Messages sent from the Host (PC) to the Client.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum RcHostMessage {
    /// Screen resolution information.
    ScreenResolution {
        width: u32,
        height: u32,
    },
    /// Host clipboard content update.
    ClipboardUpdate {
        content: String,
        format: ClipboardFormat,
    },
    /// Periodic status update for connection quality.
    SessionStatus {
        fps: u32,
        #[serde(rename = "bitrateKbps")]
        bitrate_kbps: u32,
        #[serde(rename = "clientAlias")]
        client_alias: String,
    },
    /// Authentication response.
    AuthResponse {
        success: bool,
        requires_approval: bool,
        error_message: Option<String>,
    },
    /// Host session termination notification.
    Disconnected {
        reason: String,
    },
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_mouse_move_clamping() {
        let msg = RcClientMessage::MouseMove { dx: 5000.0, dy: -3000.0 }.sanitize().unwrap();
        if let RcClientMessage::MouseMove { dx, dy } = msg {
            assert_eq!(dx, 2000.0);
            assert_eq!(dy, -2000.0);
        } else {
            panic!("Expected MouseMove");
        }
    }

    #[test]
    fn test_nan_ignored() {
        let msg = RcClientMessage::MouseMove { dx: f64::NAN, dy: 10.0 }.sanitize();
        assert!(msg.is_none());
    }

    #[test]
    fn test_clipboard_size_limit() {
        let large_string = "a".repeat(MAX_CLIPBOARD_BYTES + 1);
        let msg = RcClientMessage::ClipboardUpdate {
            content: large_string,
            format: ClipboardFormat::Text,
        }.sanitize();
        assert!(msg.is_none());
    }
}

