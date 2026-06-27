# 🎤 VoxBox

> Native macOS app for VoxCPM2 — one-click voice synthesis & voice cloning.
> Powered by Apple Neural Engine.

[![Platform](https://img.shields.io/badge/platform-macOS%2014+-blue)](https://github.com/sundaylee91/VoxBox)
[![Swift](https://img.shields.io/badge/swift-5.9%2B-orange)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

---

## ✨ What is VoxBox?

VoxBox wraps [VoxCPM2](https://github.com/0seba/VoxCPMANE) — a state-of-the-art TTS model that runs entirely on Apple Neural Engine — into a beautiful, native macOS experience:

- 🎙️ **Text-to-Speech** — Type text, get natural speech in real-time
- 🧬 **Voice Cloning** — Upload a 3-second audio clip, clone the voice
- ⚡ **Streaming** — Audio plays as it's generated, no waiting
- 🍎 **Native** — Runs on Apple Neural Engine, fully offline
- 🪄 **No Terminal** — Menu bar app, one click to start

---

## 🖥️ Screenshots

> *(Coming soon — once we build and run!)*

```
┌──────────────────────────────────────────────────────────┐
│  🎤 VoxBox                                           — □ ✕│
│  ┌────────────────────────────────────────────────────┐  │
│  │                                                    │  │
│  │   ┌────────────────────────────────────────────┐   │  │
│  │   │         VoxCPM2 Playground                 │   │  │
│  │   │  ┌─────────────────────────────────────┐   │   │  │
│  │   │  │  Text input area                    │   │   │  │
│  │   │  │  [Generate Speech] [Clone Voice]    │   │   │  │
│  │   │  │  ▶ Stream / ⏸ Stop                  │   │   │  │
│  │   │  └─────────────────────────────────────┘   │   │  │
│  │   └────────────────────────────────────────────┘   │  │
│  │                                                    │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

---

## 📋 Requirements

| What | Minimum |
|------|---------|
| macOS | **14.0 (Sonoma)** or later |
| Chip | **Apple Silicon** (M1/M2/M3/M4) |
| RAM | 8GB (16GB recommended) |
| Python | 3.10–3.12 (auto-detected, or install via Homebrew) |
| Disk | ~5GB free (models ~3.2GB) |

---

## 🚀 Quick Start

### 1. Clone & Open

```bash
git clone https://github.com/sundaylee91/VoxBox.git
cd VoxBox
```

### 2. Open in Xcode

```bash
open VoxBox.xcodeproj
```

### 3. Build & Run

Press `⌘R` in Xcode. On first launch, VoxBox will:

1. 🔍 Detect your Python 3.10–3.12 installation
2. 📦 `pip install voxcpmane2` (if not installed)
3. 📥 Download CoreML models from HuggingFace (~3.2GB)
4. 🟢 Start the server and open the playground

---

## 🏗️ Project Structure

```
VoxBox/
├── VoxBox.xcodeproj              # Xcode project
├── VoxBox/                       # App source
│   ├── VoxBoxApp.swift           # @main entry point
│   ├── ContentView.swift         # Root view with state machine
│   ├── ServerManager.swift       # Python backend lifecycle
│   ├── MenuBarController.swift   # Menu bar extra
│   ├── WebView.swift             # WKWebView wrapper
│   ├── ModelDownloadView.swift   # Model download progress
│   ├── SettingsView.swift        # Preferences
│   ├── LaunchView.swift          # Welcome / first-launch view
│   ├── LoadingView.swift         # Spinner while starting
│   ├── ErrorView.swift           # Error state with retry
│   ├── Assets.xcassets/          # App icon & assets
│   ├── Info.plist                # Bundle configuration
│   └── VoxBox.entitlements       # Code signing
├── scripts/
│   ├── bootstrap.sh              # One-click dev setup
│   └── build_dmg.sh              # Package .dmg for distribution
├── README.md
└── LICENSE
```

---

## 🎛️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     VoxBox.app                           │
│  ┌───────────────────────────────────────────────────┐  │
│  │              SwiftUI Layer                         │  │
│  │  ┌──────────┐  ┌────────────────────────────────┐ │  │
│  │  │ MenuBar  │  │     WKWebView                   │ │  │
│  │  │ Extra    │  │  http://127.0.0.1:8650          │ │  │
│  │  │ 🎤 🔊    │  │  ┌──────────────────────────┐  │ │  │
│  │  │ Start    │  │  │  VoxCPM2 Playground      │  │ │  │
│  │  │ Stop     │  │  │  (index.html)            │  │ │  │
│  │  │ Settings │  │  └──────────────────────────┘  │ │  │
│  │  └──────────┘  └────────────────────────────────┘ │  │
│  └───────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────┐  │
│  │           ServerManager (ObservableObject)         │  │
│  │  • Python detection & version check               │  │
│  │  • pip install voxcpmane2                         │  │
│  │  • Model download progress parsing                │  │
│  │  • Subprocess lifecycle (launch/health/stop)      │  │
│  │  • Port conflict resolution                       │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

---

## 🧪 Development

```bash
# Bootstrap dev environment
./scripts/bootstrap.sh

# Build for release
xcodebuild -project VoxBox.xcodeproj -scheme VoxBox -configuration Release build

# Package as DMG
./scripts/build_dmg.sh
```

---

## 📦 Distribution

VoxBox is distributed as a **standalone .dmg** (not via App Store, to avoid sandbox restrictions on local servers).

1. Build Release configuration in Xcode
2. Run `./scripts/build_dmg.sh`
3. Notarize with Apple: `xcrun notarytool submit VoxBox.dmg ...`
4. Distribute via GitHub Releases

---

## ⚠️ Known Limitations

- **8GB Macs**: Model loads ~3-6GB into memory; close other apps for best results
- **Intel Macs**: Not supported (VoxCPM2 requires Apple Neural Engine)
- **macOS < 14**: Untested; may work but not officially supported
- **Port 8650**: If occupied, VoxBox auto-selects an alternative

---

## 🙏 Credits

- **[VoxCPMANE](https://github.com/0seba/VoxCPMANE)** — The incredible CoreML port of VoxCPM2 by [@0seba](https://github.com/0seba)
- **[VoxCPM2](https://github.com/OpenBMB/VoxCPM2)** — Original model by OpenBMB
- **[CoreMLTools](https://github.com/apple/coremltools)** — Apple's CoreML conversion toolkit

---

## 📄 License

MIT © 2026 VoxBox contributors. See [LICENSE](LICENSE).

VoxBox wraps VoxCPMANE which is also MIT-licensed.
