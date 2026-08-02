# Installation

## Requirements

- **macOS 14.0+** (Sonoma or later)
- **Apple Silicon** (M1/M2/M3/M4 — MLX requires Metal)
- **Python 3.12+** with `mlx-lm`, `fastapi`, `uvicorn`, `httpx`

## Download (recommended)

1. Download the latest `PaglaMLX.dmg` from the [Releases page](https://github.com/paglaai/PaglaMLX/releases).
2. Open the DMG and drag `PaglaMLX.app` to your Applications folder.
3. Open the app.

## Python dependencies

PaglaMLX uses `mlx_lm.server` to serve models. Install the required packages:

```bash
pip3 install mlx-lm fastapi uvicorn httpx
```

If you prefer a virtual environment:

```bash
python3 -m venv ~/.venv/paglamlx
source ~/.venv/paglamlx/bin/activate
pip3 install mlx-lm fastapi uvicorn httpx
```

Then point PaglaMLX to this Python in **Settings → Python**.

## Build from source

```bash
git clone https://github.com/paglaai/PaglaMLX.git
cd PaglaMLX
./build_dmg.sh
```

This compiles the release binary, creates a signed `.app` bundle, and packages it into `PaglaMLX.dmg`.

### Build and run directly

```bash
git clone https://github.com/paglaai/PaglaMLX.git
cd PaglaMLX
swift build -c release
open .build/release/PaglaMLX
```

### Open in Xcode

```bash
open Package.swift
```

Then select the `PaglaMLX` scheme and run.
