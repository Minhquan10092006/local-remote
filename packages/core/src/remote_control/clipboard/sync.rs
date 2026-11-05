//! Native Clipboard Synchronization

use std::time::Instant;

pub struct ClipboardSync {
    last_text: Option<String>,
    last_sync_time: Instant,
}

impl ClipboardSync {
    pub fn new() -> Self {
        Self {
            last_text: None,
            last_sync_time: Instant::now(),
        }
    }

    /// Reads clipboard content from OS if it has changed since last check.
    pub fn poll_local_clipboard(&mut self) -> Result<Option<String>, String> {
        #[cfg(target_os = "windows")]
        {
            use clipboard_win::{get_clipboard, formats};
            match get_clipboard::<String, _>(formats::Unicode) {
                Ok(text) => {
                    if self.last_text.as_deref() != Some(&text) {
                        self.last_text = Some(text.clone());
                        self.last_sync_time = Instant::now();
                        return Ok(Some(text));
                    }
                }
                Err(e) => {
                    // Clipboard may be temporarily locked by another app
                    log::trace!("Clipboard read skipped: {:?}", e);
                }
            }
        }
        Ok(None)
    }

    /// Sets the local clipboard content received from remote peer.
    pub fn write_to_clipboard(&mut self, text: &str) -> Result<(), String> {
        self.last_text = Some(text.to_string());
        self.last_sync_time = Instant::now();

        #[cfg(target_os = "windows")]
        {
            use clipboard_win::{set_clipboard, formats};
            set_clipboard(formats::Unicode, text).map_err(|e| format!("Failed to write clipboard: {:?}", e))?;
        }
        log::debug!("Clipboard updated with {} bytes", text.len());
        Ok(())
    }
}

