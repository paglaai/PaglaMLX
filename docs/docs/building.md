# Building from Source

## Prerequisites

- Xcode 15+ or the Xcode Command Line Tools
- Swift 5.9+

## Build

```bash
git clone https://github.com/paglaai/PaglaMLX.git
cd PaglaMLX
swift build -c release
```

The binary is at `.build/release/PaglaMLX`.

## Build DMG

```bash
./build_dmg.sh
```

This script:
1. Builds the release binary.
2. Creates `PaglaMLX.app` bundle with `Info.plist` and `AppIcon.icns`.
3. Ad-hoc signs the bundle.
4. Packages into `PaglaMLX.dmg` with a staging directory that includes an `/Applications` symlink for drag-and-drop install.

## Open in Xcode

```bash
open Package.swift
```

Select the `PaglaMLX` scheme and run (⌘R).

## Package structure

```
PaglaMLX/
├── Sources/                    # Swift source files
│   ├── PaglaMLXApp.swift      # App entry point
│   ├── ContentView.swift       # Main view
│   ├── MenuBarView.swift       # Menu bar controller
│   ├── SettingsView.swift      # Settings UI (8 tabs)
│   ├── SettingsManager.swift   # UserDefaults persistence
│   ├── ModelOrchestrator.swift # Model process lifecycle
│   ├── RoutingGateway.swift    # Embedded Python gateway
│   ├── IntegrationManager.swift # Config patching
│   ├── AnthropicProxy.swift    # Protocol translation manager
│   ├── Preflight.swift         # Validation checks
│   ├── PreflightView.swift     # Preflight UI
│   ├── RemoteAccessManager.swift # Cloudflare tunnel
│   ├── TunnelManager.swift     # Tunnel process management
│   ├── QRCodeView.swift        # Share QR code
│   ├── TextEditorView.swift    # Prompt editor
│   └── Models.swift            # Shared data types
├── PaglaMLX-Info.plist        # Bundle info
├── AppIcon.icns                # Application icon
├── Launcher.applescript        # Automated launcher
├── build_dmg.sh                # DMG packaging script
├── Package.swift               # Swift Package Manager
├── docs/                       # Docusaurus documentation site
└── README.md
```

## Code signing

The DMG script uses ad-hoc signing (`codesign --sign -`). For distribution, you may want to replace this with a valid Apple Developer ID certificate.
