use std::time::{Duration, Instant};
use sha2::{Digest, Sha256};
use crate::remote_control::protocol::{RcClientMessage, RcHostMessage};

pub const MAX_PIN_ATTEMPTS: u32 = 5;
pub const SESSION_TIMEOUT: Duration = Duration::from_secs(15);

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RcSessionState {
    Idle,
    Listening,
    AwaitingAuth,
    AwaitingApproval,
    Connected,
    LockedOut,
}

#[derive(Debug, Clone)]
pub struct RcSessionConfig {
    pub pin_hash: Option<String>,
    pub pin_salt: Option<String>,
    pub target_fps: u32,
    pub require_approval: bool,
}

impl Default for RcSessionConfig {
    fn default() -> Self {
        Self {
            pin_hash: None,
            pin_salt: None,
            target_fps: 60,
            require_approval: true,
        }
    }
}

pub struct RcSession {
    config: RcSessionConfig,
    state: RcSessionState,
    client_alias: Option<String>,
    failed_attempts: u32,
    last_activity: Instant,
    session_start: Option<Instant>,
    screen_width: u32,
    screen_height: u32,
}

impl RcSession {
    pub fn new(config: RcSessionConfig, screen_width: u32, screen_height: u32) -> Self {
        Self {
            config,
            state: RcSessionState::Idle,
            client_alias: None,
            failed_attempts: 0,
            last_activity: Instant::now(),
            session_start: None,
            screen_width,
            screen_height,
        }
    }

    /// Hashes a PIN with a salt using SHA-256.
    pub fn hash_pin(pin: &str, salt: &str) -> String {
        let mut hasher = Sha256::new();
        hasher.update(salt.as_bytes());
        hasher.update(pin.as_bytes());
        format!("{:x}", hasher.finalize())
    }

    pub fn set_pin(&mut self, pin: Option<&str>) {
        if let Some(pin) = pin {
            let salt = format!("{:x}", rand::random::<u64>());
            self.config.pin_hash = Some(Self::hash_pin(pin, &salt));
            self.config.pin_salt = Some(salt);
        } else {
            self.config.pin_hash = None;
            self.config.pin_salt = None;
        }
    }

    pub fn start_listening(&mut self) {
        self.state = RcSessionState::Listening;
        self.client_alias = None;
        self.session_start = None;
        self.last_activity = Instant::now();
    }

    pub fn stop(&mut self) {
        self.state = RcSessionState::Idle;
        self.client_alias = None;
        self.session_start = None;
    }

    pub fn state(&self) -> RcSessionState {
        self.state
    }

    pub fn client_alias(&self) -> Option<&str> {
        self.client_alias.as_deref()
    }

    pub fn session_duration(&self) -> Option<Duration> {
        self.session_start.map(|start| start.elapsed())
    }

    pub fn authenticate(&mut self, pin: Option<&str>, client_name: &str) -> Result<bool, &'static str> {
        if self.failed_attempts >= MAX_PIN_ATTEMPTS {
            self.state = RcSessionState::LockedOut;
            return Err("Too many failed PIN attempts. Host locked.");
        }

        if let (Some(expected_hash), Some(salt)) = (&self.config.pin_hash, &self.config.pin_salt) {
            match pin {
                Some(provided_pin) => {
                    let hashed = Self::hash_pin(provided_pin, salt);
                    if hashed != *expected_hash {
                        self.failed_attempts += 1;
                        if self.failed_attempts >= MAX_PIN_ATTEMPTS {
                            self.state = RcSessionState::LockedOut;
                        }
                        return Ok(false);
                    }
                }
                None => {
                    self.failed_attempts += 1;
                    return Ok(false);
                }
            }
        }

        // Authentication successful: reset failed attempts
        self.failed_attempts = 0;
        self.client_alias = Some(client_name.to_string());
        self.last_activity = Instant::now();

        if self.config.require_approval {
            self.state = RcSessionState::AwaitingApproval;
        } else {
            self.state = RcSessionState::Connected;
            self.session_start = Some(Instant::now());
        }

        Ok(true)
    }

    pub fn approve_connection(&mut self) -> bool {
        if self.state == RcSessionState::AwaitingApproval {
            self.state = RcSessionState::Connected;
            self.session_start = Some(Instant::now());
            self.last_activity = Instant::now();
            true
        } else {
            false
        }
    }

    pub fn reject_connection(&mut self) {
        self.state = RcSessionState::Listening;
        self.client_alias = None;
        self.session_start = None;
    }

    pub fn touch_activity(&mut self) {
        self.last_activity = Instant::now();
    }

    pub fn is_timed_out(&self) -> bool {
        if self.state == RcSessionState::Connected {
            self.last_activity.elapsed() > SESSION_TIMEOUT
        } else {
            false
        }
    }

    pub fn initial_host_message(&self) -> RcHostMessage {
        RcHostMessage::ScreenResolution {
            width: self.screen_width,
            height: self.screen_height,
        }
    }

    pub fn status_message(&self, bitrate_kbps: u32) -> RcHostMessage {
        RcHostMessage::SessionStatus {
            fps: self.config.target_fps,
            bitrate_kbps,
            client_alias: self.client_alias.clone().unwrap_or_else(|| "Unknown".to_string()),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_pin_verification_and_lockout() {
        let mut session = RcSession::new(RcSessionConfig::default(), 1920, 1080);
        session.set_pin(Some("1234"));

        for _ in 0..4 {
            let res = session.authenticate(Some("9999"), "Phone").unwrap();
            assert!(!res);
            assert_ne!(session.state(), RcSessionState::LockedOut);
        }

        // 5th attempt fails -> locked out
        let res = session.authenticate(Some("9999"), "Phone").unwrap();
        assert!(!res);
        assert_eq!(session.state(), RcSessionState::LockedOut);

        // 6th attempt returns Err
        let res = session.authenticate(Some("1234"), "Phone");
        assert!(res.is_err());
    }
}

