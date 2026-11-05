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

#[frb(sync)]
pub fn execute_client_json_message(json_str: String) -> Result<(), String> {
    handle_client_json_message(json_str)
}

pub fn handle_client_json_message(json_str: String) -> Result<(), String> {
    let msg: RcClientMessage = serde_json::from_str(&json_str).map_err(|e| e.to_string())?;
    let sanitized = msg.sanitize().ok_or_else(|| "Message failed security sanitization".to_string())?;

    let mut guard = HOST_CTX.lock().map_err(|e| e.to_string())?;
    if let Some(ctx) = guard.as_mut() {
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
                let _ = ctx.clipboard.write_to_clipboard(content);
            }
            _ => {
                ctx.session.touch_activity();
                ctx.injector.handle_message(&sanitized)?;
            }
        }
    } else {
        // Fallback standalone injector if host isn't started via FFI
        let mut injector = HidInjector::new(1920, 1080);
        let _ = injector.handle_message(&sanitized);
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

/// High-speed native screen capture for Windows (output as 32-bit BMP bytes).
#[frb(sync)]
pub fn capture_screen_frame() -> Vec<u8> {
    #[cfg(target_os = "windows")]
    unsafe {
        capture_windows_screen_bmp()
    }
    #[cfg(not(target_os = "windows"))]
    {
        Vec::new()
    }
}

#[cfg(target_os = "windows")]
unsafe fn capture_windows_screen_bmp() -> Vec<u8> {
    const SRCCOPY: u32 = 0x00CC0020;
    const BI_RGB: u32 = 0;

    extern "system" {
        fn GetDC(hwnd: *mut std::ffi::c_void) -> *mut std::ffi::c_void;
        fn ReleaseDC(hwnd: *mut std::ffi::c_void, hdc: *mut std::ffi::c_void) -> i32;
        fn CreateCompatibleDC(hdc: *mut std::ffi::c_void) -> *mut std::ffi::c_void;
        fn DeleteDC(hdc: *mut std::ffi::c_void) -> i32;
        fn CreateCompatibleBitmap(hdc: *mut std::ffi::c_void, cx: i32, cy: i32) -> *mut std::ffi::c_void;
        fn SelectObject(hdc: *mut std::ffi::c_void, h: *mut std::ffi::c_void) -> *mut std::ffi::c_void;
        fn DeleteObject(ho: *mut std::ffi::c_void) -> i32;
        fn BitBlt(hdc: *mut std::ffi::c_void, x: i32, y: i32, cx: i32, cy: i32, hdc_src: *mut std::ffi::c_void, x1: i32, y1: i32, rop: u32) -> i32;
        fn GetSystemMetrics(nIndex: i32) -> i32;
        fn GetDIBits(
            hdc: *mut std::ffi::c_void,
            hbm: *mut std::ffi::c_void,
            start: u32,
            cLines: u32,
            lpvBits: *mut std::ffi::c_void,
            lpbmi: *mut std::ffi::c_void,
            usage: u32,
        ) -> i32;
    }

    #[repr(C)]
    struct BITMAPINFOHEADER {
        bi_size: u32,
        bi_width: i32,
        bi_height: i32,
        bi_planes: u16,
        bi_bit_count: u16,
        bi_compression: u32,
        bi_size_image: u32,
        bi_x_pels_per_meter: i32,
        bi_y_pels_per_meter: i32,
        bi_clr_used: u32,
        bi_clr_important: u32,
    }

    let screen_w = GetSystemMetrics(0); // SM_CXSCREEN
    let screen_h = GetSystemMetrics(1); // SM_CYSCREEN

    if screen_w <= 0 || screen_h <= 0 {
        return Vec::new();
    }

    let hdc_screen = GetDC(std::ptr::null_mut());
    let hdc_mem = CreateCompatibleDC(hdc_screen);
    let hbm = CreateCompatibleBitmap(hdc_screen, screen_w, screen_h);
    let old_bm = SelectObject(hdc_mem, hbm);

    BitBlt(hdc_mem, 0, 0, screen_w, screen_h, hdc_screen, 0, 0, SRCCOPY);

    let row_size = ((screen_w * 32 + 31) / 32) * 4;
    let data_size = (row_size * screen_h) as usize;
    let file_size = 54 + data_size;

    let mut bmp_bytes: Vec<u8> = Vec::with_capacity(file_size);
    // BMP Header (14 bytes)
    bmp_bytes.extend_from_slice(&[0x42, 0x4D]); // 'BM'
    bmp_bytes.extend_from_slice(&(file_size as u32).to_le_bytes());
    bmp_bytes.extend_from_slice(&[0, 0, 0, 0]); // Reserved
    bmp_bytes.extend_from_slice(&54u32.to_le_bytes()); // Offset to data

    // DIB Header (40 bytes - BITMAPINFOHEADER)
    bmp_bytes.extend_from_slice(&40u32.to_le_bytes());
    bmp_bytes.extend_from_slice(&(screen_w as i32).to_le_bytes());
    bmp_bytes.extend_from_slice(&(screen_h as i32).to_le_bytes()); // Bottom-up
    bmp_bytes.extend_from_slice(&1u16.to_le_bytes()); // Planes
    bmp_bytes.extend_from_slice(&32u16.to_le_bytes()); // BitCount
    bmp_bytes.extend_from_slice(&BI_RGB.to_le_bytes()); // Compression
    bmp_bytes.extend_from_slice(&(data_size as u32).to_le_bytes());
    bmp_bytes.extend_from_slice(&2835i32.to_le_bytes());
    bmp_bytes.extend_from_slice(&2835i32.to_le_bytes());
    bmp_bytes.extend_from_slice(&0u32.to_le_bytes());
    bmp_bytes.extend_from_slice(&0u32.to_le_bytes());

    let pixel_start = bmp_bytes.len();
    bmp_bytes.resize(file_size, 0);

    let mut bmi = BITMAPINFOHEADER {
        bi_size: 40,
        bi_width: screen_w,
        bi_height: screen_h,
        bi_planes: 1,
        bi_bit_count: 32,
        bi_compression: BI_RGB,
        bi_size_image: data_size as u32,
        bi_x_pels_per_meter: 0,
        bi_y_pels_per_meter: 0,
        bi_clr_used: 0,
        bi_clr_important: 0,
    };

    GetDIBits(
        hdc_mem,
        hbm,
        0,
        screen_h as u32,
        bmp_bytes[pixel_start..].as_mut_ptr() as *mut std::ffi::c_void,
        &mut bmi as *mut _ as *mut std::ffi::c_void,
        0, // DIB_RGB_COLORS
    );

    SelectObject(hdc_mem, old_bm);
    DeleteObject(hbm);
    DeleteDC(hdc_mem);
    ReleaseDC(std::ptr::null_mut(), hdc_screen);

    bmp_bytes
}
