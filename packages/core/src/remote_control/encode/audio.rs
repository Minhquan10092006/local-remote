//! Opus 48kHz Stereo Audio Encoder Interface

pub struct AudioEncoderConfig {
    pub sample_rate: u32,
    pub channels: u16,
    pub bitrate_kbps: u32,
}

pub struct AudioEncoder {
    config: AudioEncoderConfig,
}

impl AudioEncoder {
    pub fn new(config: AudioEncoderConfig) -> Self {
        Self { config }
    }

    pub fn encode_samples(&mut self, _pcm_samples: &[f32]) -> Result<Vec<u8>, String> {
        // Encoders yield 20ms Opus frames for WebRTC audio tracks
        Ok(Vec::new())
    }

    pub fn config(&self) -> &AudioEncoderConfig {
        &self.config
    }
}

