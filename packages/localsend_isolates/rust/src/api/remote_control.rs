//! Remote Control FFI API for Flutter
//!
//! Emits events via StreamSink<String> (JSON-serialized) to ensure MSVC compatibility
//! and avoid SseEncode trait-bound issues with custom Rust enums (Critical Lesson 8.3).

use std::sync::Mutex;
use flutter_rust_bridge::frb;
use lazy_static::lazy_static;
use serde_json::json;

use localsend_core::remote_control::{
    protocol::{RcClientMessage, RcHostMessage},
    session::{RcSession, RcSessionConfig, RcSessionState},
    hid::HidInjector,
    clipboard::ClipboardSync,
};

use crate::frb_generated::StreamSink;

struct HostContext {
    session: RcSession,
    injector: HidInjector,
    clipboard: ClipboardSync,
    event_sink: Option<StreamSink<String>>,
}

lazy_static! {
    static ref HOST_CTX: Mutex<Option<HostContext>> = Mutex::new(None);
}

#[frb(sync)]
pub fn init_rc_engine() {
    log::info!("LocalSend Remote Control FFI Engine initialized");
}

pub fn start_rc_host(
    pin: Option<String>,
    target_fps: u32,
    screen_width: u32,
    screen_height: u32,
    event_sink: StreamSink<String>,
) -> Result<(), String> {
    let mut config = RcSessionConfig::default();
    config.target_fps = target_fps;
    config.require_approval = true;

    let mut session = RcSession::new(config, screen_width, screen_height);
    if let Some(ref p) = pin {
        session.set_pin(Some(p));
    }
    session.start_listening();

    let injector = HidInjector::new(screen_width, screen_height);
    let clipboard = ClipboardSync::new();

    let initial_msg = session.initial_host_message();
    if let Ok(serialized) = serde_json::to_string(&initial_msg) {
        let _ = event_sink.add(serialized);
    }

    let mut guard = HOST_CTX.lock().map_err(|e| e.to_string())?;
    *guard = Some(HostContext {
        session,
        injector,
        clipboard,
        event_sink: Some(event_sink),
    });

    log::info!("Remote Control Host started listening. FPS: {}, PIN protected: {}", target_fps, pin.is_some());
    Ok(())
}

pub fn stop_rc_host() -> Result<(), String> {
    let mut guard = HOST_CTX.lock().map_err(|e| e.to_string())?;
    if let Some(ctx) = guard.as_mut() {
        ctx.session.stop();
        if let Some(sink) = &ctx.event_sink {
            let msg = RcHostMessage::Disconnected {
                reason: "Host stopped remote control service".to_string(),
            };
            if let Ok(serialized) = serde_json::to_string(&msg) {
                let _ = sink.add(serialized);
            }
        }
    }
    *guard = None;
    log::info!("Remote Control Host stopped");
    Ok(())
}

pub fn handle_client_json_message(json_str: String) -> Result<(), String> {
    let msg: RcClientMessage = serde_json::from_str(&json_str).map_err(|e| e.to_string())?;
    let sanitized = msg.sanitize().ok_or_else(|| "Message failed security sanitization".to_string())?;

    let mut guard = HOST_CTX.lock().map_err(|e| e.to_string())?;
    let ctx = guard.as_mut().ok_or_else(|| "Host is not running".to_string())?;

    match &sanitized {
        RcClientMessage::AuthRequest { pin, client_name } => {
            let auth_res = ctx.session.authenticate(pin.as_deref(), client_name);
            match auth_res {
                Ok(true) => {
                    let needs_approval = ctx.session.state() == RcSessionState::AwaitingApproval;
                    let resp = RcHostMessage::AuthResponse {
                        success: true,
                        requires_approval: needs_approval,
                        error_message: None,
                    };
                    if let Some(sink) = &ctx.event_sink {
                        let _ = sink.add(serde_json::to_string(&resp).unwrap_or_default());
                    }
                }
                Ok(false) => {
                    let resp = RcHostMessage::AuthResponse {
                        success: false,
                        requires_approval: false,
                        error_message: Some("Invalid PIN".to_string()),
                    };
                    if let Some(sink) = &ctx.event_sink {
                        let _ = sink.add(serde_json::to_string(&resp).unwrap_or_default());
                    }
                }
                Err(err_msg) => {
                    let resp = RcHostMessage::AuthResponse {
                        success: false,
                        requires_approval: false,
                        error_message: Some(err_msg.to_string()),
                    };
                    if let Some(sink) = &ctx.event_sink {
                        let _ = sink.add(serde_json::to_string(&resp).unwrap_or_default());
                    }
                }
            }
        }
        RcClientMessage::ClipboardUpdate { content, .. } => {
            if ctx.session.state() == RcSessionState::Connected {
                let _ = ctx.clipboard.write_to_clipboard(content);
            }
        }
        _ => {
            if ctx.session.state() == RcSessionState::Connected {
                ctx.session.touch_activity();
                ctx.injector.handle_message(&sanitized)?;
            }
        }
    }

    Ok(())
}

pub fn approve_remote_client() -> Result<bool, String> {
    let mut guard = HOST_CTX.lock().map_err(|e| e.to_string())?;
    let ctx = guard.as_mut().ok_or_else(|| "Host not running".to_string())?;

    let approved = ctx.session.approve_connection();
    if approved {
        if let Some(sink) = &ctx.event_sink {
            let msg = json!({
                "type": "ClientApproved",
                "client": ctx.session.client_alias().unwrap_or("Unknown")
            });
            let _ = sink.add(msg.to_string());
        }
    }
    Ok(approved)
}

pub fn reject_remote_client() -> Result<(), String> {
    let mut guard = HOST_CTX.lock().map_err(|e| e.to_string())?;
    let ctx = guard.as_mut().ok_or_else(|| "Host not running".to_string())?;

    ctx.session.reject_connection();
    if let Some(sink) = &ctx.event_sink {
        let msg = RcHostMessage::Disconnected {
            reason: "Host rejected connection request".to_string(),
        };
        if let Ok(serialized) = serde_json::to_string(&msg) {
            let _ = sink.add(serialized);
        }
    }
    Ok(())
}

#[frb(sync)]
pub fn poll_host_status_json() -> String {
    let guard = match HOST_CTX.lock() {
        Ok(g) => g,
        Err(_) => return json!({ "running": false }).to_string(),
    };

    if let Some(ctx) = guard.as_ref() {
        json!({
            "running": true,
            "state": format!("{:?}", ctx.session.state()),
            "client": ctx.session.client_alias(),
            "durationSeconds": ctx.session.session_duration().map(|d| d.as_secs()).unwrap_or(0),
        }).to_string()
    } else {
        json!({ "running": false }).to_string()
    }
}
