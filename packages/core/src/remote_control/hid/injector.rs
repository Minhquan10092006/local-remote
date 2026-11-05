//! HID Input Injector (Mouse & Keyboard)

use crate::remote_control::protocol::{MouseButtonType, RcClientMessage};

pub struct HidInjector {
    screen_width: u32,
    screen_height: u32,
    #[cfg(target_os = "windows")]
    enigo: Option<enigo::Enigo>,
}

impl HidInjector {
    pub fn new(screen_width: u32, screen_height: u32) -> Self {
        #[cfg(target_os = "windows")]
        let enigo = {
            use enigo::Settings;
            enigo::Enigo::new(&Settings::default()).ok()
        };

        Self {
            screen_width,
            screen_height,
            #[cfg(target_os = "windows")]
            enigo,
        }
    }

    pub fn set_screen_dimensions(&mut self, width: u32, height: u32) {
        self.screen_width = width;
        self.screen_height = height;
    }

    pub fn handle_message(&mut self, message: &RcClientMessage) -> Result<(), String> {
        match message {
            RcClientMessage::MouseMove { dx, dy } => self.move_mouse_relative(*dx, *dy),
            RcClientMessage::MouseAbsolute { x, y } => self.move_mouse_absolute(*x, *y),
            RcClientMessage::MouseButton { button, pressed } => self.mouse_button(*button, *pressed),
            RcClientMessage::MouseScroll { dx, dy } => self.mouse_scroll(*dx, *dy),
            RcClientMessage::KeyEvent { key, pressed, modifiers } => {
                self.key_event(key, *pressed, modifiers)
            }
            _ => Ok(()),
        }
    }

    pub fn move_mouse_relative(&mut self, dx: f64, dy: f64) -> Result<(), String> {
        #[cfg(target_os = "windows")]
        if let Some(enigo) = &mut self.enigo {
            use enigo::Mouse;
            let _ = enigo.move_mouse(dx as i32, dy as i32, enigo::Coordinate::Rel);
            return Ok(());
        }
        log::debug!("Simulating relative mouse move: dx={}, dy={}", dx, dy);
        Ok(())
    }

    pub fn move_mouse_absolute(&mut self, x: f64, y: f64) -> Result<(), String> {
        let abs_x = (x * self.screen_width as f64) as i32;
        let abs_y = (y * self.screen_height as f64) as i32;

        #[cfg(target_os = "windows")]
        if let Some(enigo) = &mut self.enigo {
            use enigo::Mouse;
            let _ = enigo.move_mouse(abs_x, abs_y, enigo::Coordinate::Abs);
            return Ok(());
        }
        log::debug!("Simulating absolute mouse move: ({}, {}) -> pixel ({}, {})", x, y, abs_x, abs_y);
        Ok(())
    }

    pub fn mouse_button(&mut self, button: MouseButtonType, pressed: bool) -> Result<(), String> {
        #[cfg(target_os = "windows")]
        if let Some(enigo) = &mut self.enigo {
            use enigo::{Button, Direction, Mouse};
            let b = match button {
                MouseButtonType::Left => Button::Left,
                MouseButtonType::Right => Button::Right,
                MouseButtonType::Middle => Button::Middle,
            };
            let dir = if pressed { Direction::Press } else { Direction::Release };
            let _ = enigo.button(b, dir);
            return Ok(());
        }
        log::debug!("Simulating mouse button {:?}, pressed={}", button, pressed);
        Ok(())
    }

    pub fn mouse_scroll(&mut self, dx: f64, dy: f64) -> Result<(), String> {
        #[cfg(target_os = "windows")]
        if let Some(enigo) = &mut self.enigo {
            use enigo::{Axis, Mouse};
            if dy.abs() > 0.0 {
                let _ = enigo.scroll(dy as i32, Axis::Vertical);
            }
            if dx.abs() > 0.0 {
                let _ = enigo.scroll(dx as i32, Axis::Horizontal);
            }
            return Ok(());
        }
        log::debug!("Simulating mouse scroll: dx={}, dy={}", dx, dy);
        Ok(())
    }

    pub fn key_event(&mut self, key: &str, pressed: bool, _modifiers: &[String]) -> Result<(), String> {
        #[cfg(target_os = "windows")]
        if let Some(enigo) = &mut self.enigo {
            use enigo::{Direction, Key, Keyboard};
            let dir = if pressed { Direction::Press } else { Direction::Release };

            let parsed_key = match key.to_lowercase().as_str() {
                "ctrl" | "control" => Some(Key::Control),
                "alt" => Some(Key::Alt),
                "shift" => Some(Key::Shift),
                "win" | "meta" => Some(Key::Meta),
                "enter" | "return" => Some(Key::Return),
                "backspace" => Some(Key::Backspace),
                "delete" => Some(Key::Delete),
                "escape" | "esc" => Some(Key::Escape),
                "tab" => Some(Key::Tab),
                "space" => Some(Key::Space),
                "up" => Some(Key::UpArrow),
                "down" => Some(Key::DownArrow),
                "left" => Some(Key::LeftArrow),
                "right" => Some(Key::RightArrow),
                "home" => Some(Key::Home),
                "end" => Some(Key::End),
                "pageup" => Some(Key::PageUp),
                "pagedown" => Some(Key::PageDown),
                "f1" => Some(Key::F1),
                "f2" => Some(Key::F2),
                "f3" => Some(Key::F3),
                "f4" => Some(Key::F4),
                "f5" => Some(Key::F5),
                "f6" => Some(Key::F6),
                "f7" => Some(Key::F7),
                "f8" => Some(Key::F8),
                "f9" => Some(Key::F9),
                "f10" => Some(Key::F10),
                "f11" => Some(Key::F11),
                "f12" => Some(Key::F12),
                _ => None,
            };

            if let Some(k) = parsed_key {
                let _ = enigo.key(k, dir);
            } else if let Some(first_char) = key.chars().next() {
                if key.chars().count() == 1 {
                    let _ = enigo.key(Key::Unicode(first_char), dir);
                }
            }
            return Ok(());
        }

        log::debug!("Simulating key event: key={}, pressed={}", key, pressed);
        Ok(())
    }
}

