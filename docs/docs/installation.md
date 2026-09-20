# Installation

## Requirements

- **macOS 14.0+** (Sonoma or later)
- **Apple Silicon** (M1/M2/M3/M4 — MLX requires Metal)
- **Xcode 15+ or Swift 5.9+** when building from source

PaglaMLX v1.6.0 is a native Swift application. Python is not required at runtime.

## Download (recommended)

1. Download the latest `PaglaMLX.dmg` from the [v1.6.0 release](https://github.com/paglaai/PaglaMLX/releases/tag/v1.6.0) or the [Releases page](https://github.com/paglaai/PaglaMLX/releases).
2. Open the DMG and drag `PaglaMLX.app` to your Applications folder.
3. Open the app and complete the local model setup in the menu bar.

The v1.6.0 app includes the native Swift-NIO HTTP server and MLX C++ bridge. No Python gateway, `mlx_lm.server`, FastAPI, or Uvicorn installation is needed.

## Build from source

```bash
git clone https://github.com/paglaai/PaglaMLX.git
cd PaglaMLX
swift build -c release
./build_dmg.sh
```

This compiles the release binary, creates a signed `.app` bundle, and packages it into `PaglaMLX.dmg`.

### Open in Xcode

```bash
open Package.swift
```

Then select the `PaglaMLX` scheme and run.

## First launch

1. Choose a directory containing MLX-compatible model weights.
2. Load a model from the menu-bar model picker.
3. Configure API clients to use `http://127.0.0.1:2525/v1`.
4. Retrieve or rotate the local bearer token from **Settings → Network**.

Provider API keys and bearer tokens are stored in the macOS Keychain. During an upgrade, legacy `UserDefaults` credentials are migrated only after the Keychain write succeeds.

## Release notes

See the [v1.6.0 release notes](https://github.com/paglaai/PaglaMLX/releases/tag/v1.6.0), the [architecture reference](architecture), and the [project roadmap](https://github.com/paglaai/PaglaMLX/blob/main/ROADMAP.md).

## Platform note

PaglaMLX targets macOS on Apple Silicon. The repository's C++ MLX bridge requires the Apple toolchain and Metal runtime.

## Security note

Never paste API keys or bearer tokens into logs, issue reports, or screenshots. See the repository's [security policy](https://github.com/paglaai/PaglaMLX/blob/main/SECURITY.md) for reporting guidance.

## Version

This page targets **PaglaMLX v1.6.0**.

## Runtime summary

Native Swift + Swift-NIO + C++ FFI to MLX.

## End

PaglaMLX v1.6.0.
