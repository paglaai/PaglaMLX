# Building from Source

PaglaMLX v1.6.0 is built as a native Swift package. The application, Swift-NIO HTTP server, routing core, credential store, and MLX bridge share one runtime; there is no Python gateway process to install or launch.

## Prerequisites

- Xcode 15+ or the Xcode Command Line Tools
- Swift 5.9+
- Apple Silicon macOS 14.0+

## Build

```bash
git clone https://github.com/paglaai/PaglaMLX.git
cd PaglaMLX
swift build -c release
```

The release binary is written to `.build/release/PaglaMLX`.

## Build DMG

```bash
./build_dmg.sh
```

This script:

1. Builds the release binary.
2. Creates the `PaglaMLX.app` bundle with `Info.plist` and `AppIcon.icns`.
3. Ad-hoc signs the bundle.
4. Packages `PaglaMLX.dmg` with an `/Applications` symlink for drag-and-drop installation.

## Open in Xcode

```bash
open Package.swift
```

Select the `PaglaMLX` scheme and run (⌘R).

## Package structure

```text
PaglaMLX/
├── Sources/
│   ├── PaglaMLXApp.swift          # Menu-bar application entry point
│   ├── PaglaMLXCore/              # Shared headless runtime
│   │   ├── HTTPServer.swift       # Swift-NIO HTTP server
│   │   ├── EnginePool.swift       # Model lifecycle and routing pool
│   │   ├── MLXBridge.h            # C-compatible MLX boundary
│   │   ├── KeychainStore.swift    # macOS Keychain secret storage
│   │   └── CredentialMigration.swift # Safe legacy migration
│   ├── RoutingGateway.swift       # Request routing and protocol translation
│   ├── ModelOrchestrator.swift    # Native model lifecycle
│   ├── SettingsManager.swift      # Non-secret preferences
│   └── IntegrationManager.swift   # Client configuration patching
├── Package.swift
├── PaglaMLX-Info.plist
├── AppIcon.icns
├── build_dmg.sh
├── docs/
└── ROADMAP.md
```

## C++ FFI boundary

Swift owns request handling, routing, lifecycle, and error policy. MLX-specific work crosses a narrow C-compatible bridge into the C++ implementation. Keep ownership and error conversion explicit at this boundary; do not expose C++ types directly to Swift callers.

## Credential handling

Secrets belong in `KeychainStore`, not in `UserDefaults` or logs. The migration shim is write-before-delete: it removes a legacy value only after the Keychain write succeeds.

## Code signing

The DMG script uses ad-hoc signing (`codesign --sign -`). For distribution, replace this with a valid Apple Developer ID certificate and notarization workflow.

## References

- [Architecture reference](architecture)
- [Roadmap](https://github.com/paglaai/PaglaMLX/blob/main/ROADMAP.md)
- [v1.6.0 release](https://github.com/paglaai/PaglaMLX/releases/tag/v1.6.0)
