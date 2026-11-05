# Remote Desktop Local (v2.0)

> Master Technical Architecture, UI/UX Design & Deployment Implementation for Local Desktop Control over LAN/WiFi & WebRTC.

## 🚀 Overview

Remote Desktop Local provides high-performance (30/50/60 FPS), secure, and low-latency computer control within local networks (WiFi / LAN) and P2P WebRTC. It eliminates third-party cloud dependence, keeping control and display data entirely private.

- **Host (Windows 10/11 x64):** Rust Core Engine capturing DXGI desktop video, WASAPI loopback audio, Enigo native keyboard/mouse simulation, and bidirectional clipboard synchronization.
- **Client (Android / Cross-platform):** Flutter UI with Refena State Management, MediaCodec hardware decoding, virtual touchpad gestures, and on-screen keyboard shortcut toolbar.

---

## 🛠️ Project Architecture

```
localsend/
├── Cargo.toml                              # Rust workspace root
├── rust-toolchain.toml                     # Rust toolchain config (channel = "stable")
├── pubspec.yaml                            # Flutter root pubspec
├── README.md                               # Project documentation
│
├── .github/
│   └── workflows/
│       └── build_apk.yml                   # CI/CD multiplatform builder
│
├── packages/
│   ├── core/                               # Rust native engine
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── lib.rs
│   │       └── remote_control/             # Remote desktop engine
│   │           ├── mod.rs
│   │           ├── protocol.rs             # JSON wire protocol (RcClientMessage, RcHostMessage)
│   │           ├── session.rs              # Session orchestrator & PIN rate-limiter
│   │           ├── capture/                # DXGI & WASAPI capturers
│   │           ├── encode/                 # H.264 & Opus encoders
│   │           ├── hid/                    # Enigo mouse & keyboard injector
│   │           └── clipboard/              # Native clipboard sync
│   │
│   └── localsend_isolates/                 # FFI Bridge between Flutter & Rust
│       ├── Cargo.toml
│       └── rust/                           # Flutter Rust Bridge integration
│
└── app/                                    # Flutter frontend app
    ├── pubspec.yaml
    ├── android/                            # Android Gradle setup (compileSdk 35)
    ├── windows/                            # Windows Runner
    └── lib/
        ├── model/remote_control/           # Dart protocol models
        ├── provider/remote_control/        # Refena state management
        └── pages/
            ├── tabs/remote_control_tab.dart# Remote Desktop Main Tab
            └── remote_control/             # Host settings, Client fullscreen viewer & widgets
```

---

## 🔒 5-Layer Security Model

1. **Transport Encryption:** DTLS 1.2/1.3 for input/clipboard DataChannels + SRTP for audio/video.
2. **Identity Verification:** SHA-256 fingerprint certificate exchange.
3. **PIN Gate & Anti-Brute-Force:** Optional 4-8 digit PIN with max 5 failed attempts limit (`MAX_PIN_ATTEMPTS = 5`).
4. **Host Approval Prompt:** Pop-up on host machine requiring user permission before accepting connections.
5. **Active Session Banner:** Persistent warning banner with kill switch on Host screen.

---

## 💻 Building the Project

### Prerequisites
- Flutter SDK 3.41+
- Rust 1.80+ (Stable)
- Android SDK 35 & NDK (for Android builds)
- Visual Studio C++ Build Tools (for Windows builds)

### Automated CI/CD
GitHub Actions workflow `.github/workflows/build_apk.yml` automatically builds release artifacts:
- Android APK (`RemoteDesktop-Release-APK`)
- Windows x64 Portable Package (`RemoteDesktop-Windows-x64.zip`)

