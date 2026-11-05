//! LocalSend Core Engine & Remote Desktop Library (v2.0)
//!
//! Provides native low-latency screen capture, loopback audio,
//! mouse and keyboard HID injection, clipboard synchronization,
//! and secure session management.

pub mod remote_control;

pub use remote_control::{
    protocol::{RcClientMessage, RcHostMessage, MouseButtonType, ClipboardFormat},
    session::{RcSession, RcSessionConfig, RcSessionState},
};

