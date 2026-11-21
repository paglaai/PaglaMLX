# PaglaMLX

> Apple Silicon native LLM orchestration, local model serving, and menu-bar manager for the PaglaAI ecosystem.

---

## What is PaglaMLX?

PaglaMLX is the native Apple Silicon local model runner and inference engine for the **PaglaAI** ecosystem.

It is not simply a Python wrapper around Apple's MLX library.

It is a complete, self-contained desktop system comprising a native Swift macOS menu-bar application and a high-performance local FastAPI backend. It unifies locally hosted MLX models and cloud providers behind a single local API (`http://127.0.0.1:2525/v1`) that speaks both OpenAI and Anthropic Claude protocols natively.

With PaglaMLX, developers run state-of-the-art quantized open-weights models (DeepSeek, Llama 3, Qwen 2.5, Mistral, Gemma 2) directly on Apple Silicon unified memory with zero configuration friction and instant menu-bar controls.

---

## Purpose

The purpose of this repository is to make private, local, zero-latency AI inference effortless on macOS.

This repository governs:

- Native macOS Menu-Bar Application (Swift 5.9+, SwiftUI)
- High-Performance Local Inference Server (`mlx-lm`, FastAPI, Uvicorn)
- Universal OpenAI-compatible endpoint (`POST /v1/chat/completions`)
- Universal Anthropic-compatible endpoint (`POST /v1/messages`)
- Dynamic Model Lifecycle Management (load, unload, memory footprint tracking)
- Strict 16GB Unified-Memory Enforcement to prevent system swap exhaustion
- Automated `.dmg` packaging and release pipelines (`build_dmg.sh`)
- Model Directory Auto-Discovery and Python Environment Detection

---

## Ecosystem

PaglaMLX serves as the local inference anchor for the PaglaAI ecosystem:

- **PaglaSPACE** — Highlights PaglaMLX as the flagship local product at `/products/paglamlx.html`.
- **PaglaDESIGN** — Governs the desktop app's visual identity, monochrome icons, and typography.
- **PaglaROUTER** — Acts as the upstream cloud fallback gateway when local models exceed capacity.
- **PaglaSHELL** — Directly connects terminal agent workflows to `http://127.0.0.1:2525/v1`.
- **PaglaGPT** — Enforces Apple Silicon hardware constraints (16GB memory ceilings) across designs.
- **PaglaEXTENSION** — Directly exports AI conversations into local models served by PaglaMLX.

---

## Design Philosophy

PaglaMLX adheres strictly to **PaglaDESIGN** and Apple Human Interface Guidelines:

- **Local-First Always:** Your prompts, files, and model weights never leave your Mac unless cloud fallback is explicitly enabled.
- **Memory Discipline:** Strict tracking of Metal buffer allocations ensures zero memory leaks during consecutive model reloads.
- **Native Experience:** Menu-bar controls provide instant model switching, status monitoring, and single-click server start/stop.
- **Open Standards:** Exposes standard HTTP APIs so existing developer tools, coding agents, and curl scripts work out of the box.

---

## Repository Structure

```
PaglaMLX/

README.md                  — repository purpose, architecture, and usage guide
LICENSE                    — MIT license
build_dmg.sh               — automated macOS .app and .dmg release packager
requirements.txt           — Python runtime dependencies (mlx-lm, fastapi, uvicorn)

PaglaMLXApp/               — native macOS menu-bar application (Swift)
  PaglaMLXApp.swift        — application entrypoint and menu-bar controller
  Views/                   — SwiftUI settings, model selector, and status views
  Services/                — background process manager and health observer
  Resources/               — app icons, menu-bar assets, and entitlements

server/                    — local inference server (Python)
  main.py                  — FastAPI server entrypoint and route declarations
  engine.py                — MLX model loader, tokenizer, and Metal stream executor
  adapters/                — request and response format transformers
  utils/                   — hardware detection and memory measurement

assets/                    — brand marks, banners, and diagrams
docs/                      — documentation source and API specification
```

---

## Workflow

PaglaMLX development follows the canonical PaglaAI process:

```
Vision
    ↓
Research
    ↓
Documentation
    ↓
Design
    ↓
Review
    ↓
Prototype
    ↓
Implementation
```

All builds are validated against macOS 14+ (Sonoma) and macOS 15+ (Sequoia) on M-series chips.

---

## Quickstart

### Prerequisites

- macOS 14.0 or later
- Apple Silicon Mac (M1/M2/M3/M4, Pro/Max/Ultra)
- Python 3.12+

### Option A: Pre-built macOS App (Recommended)

1. Download the latest `.dmg` release from [PaglaMLX Releases](https://github.com/paglaai/PaglaMLX/releases).
2. Open the disk image and drag **PaglaMLX** to your `/Applications` folder.
3. Launch PaglaMLX. Click the menu-bar icon, select your model cache directory, and start the engine.

### Option B: Build from Source

```bash
# Clone the repository
git clone https://github.com/paglaai/PaglaMLX.git
cd PaglaMLX

# Install Python requirements
pip install -r requirements.txt

# Build the release .app and .dmg bundle
./build_dmg.sh
```

### Making Requests

```bash
curl http://127.0.0.1:2525/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(defaults read com.paglaai.app apiKey 2>/dev/null || echo 'local')" \
  -d '{
    "model": "auto",
    "messages": [
      { "role": "user", "content": "Hello from PaglaMLX!" }
    ]
  }'
```

---

## Governance & License

PaglaMLX is developed and maintained by **AYNAGHOR** (The House of Mirror) for the PaglaAI ecosystem.

Released under the **MIT License**.
