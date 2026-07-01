# PaglaMLX

**Local LLM orchestration for Apple Silicon.** A native macOS menu‑bar app that loads, manages, and serves MLX‑compatible models through a smart reverse proxy — no CLI needed.

PaglaMLX launches each model as its own server process, keeps a live route table (`~/.lengtamlx/routes.json`), and runs a unified gateway at `127.0.0.1:2525` that speaks **OpenAI** and **Anthropic** formats natively. Any OpenAI/Anthropic‑compatible client can connect and start using your local models as if they were cloud APIs — and it falls back to real cloud providers when you ask for one you don't have locally.

---

## Features

### Model Orchestration
- **One‑click load/unload** — scan a directory of MLX models, pick one, press Play.
- **Per‑model server processes** — each model runs as an isolated `mlx_lm.server` on its own port.
- **Dynamic route table** — routes are updated in real‑time as models start and stop.
- **Multiple concurrent models** — load several models; the gateway dispatches by model name.

### Smart Gateway (`:2525/v1`)
- **OpenAI‑native** — `/v1/chat/completions`, `/v1/embeddings`, `/v1/models` — works out of the box.
- **Anthropic‑native** — `/v1/messages` is bidirectionally translated to/from OpenAI format (streaming + tool calls).
- **Auto‑Router** — request `model=auto` and the gateway picks the best local model by capability (multimodal → long context → keyword intent → default).
- **Cloud routing** — prefix‑based dispatch: `gpt‑*` → OpenAI, `claude‑*` → Anthropic, `gemini‑*` → Gemini, `openrouter/*`, `groq/*`, `together/*`.
- **Free Router** — toggle to route unrecognised model names through OpenRouter as a cost‑effective fallback.
- **Session stickiness** — once a session is routed, all subsequent requests from that session stay on the same backend.
- **Auth middleware** — optional Bearer‑token guard on all API endpoints.

### Integrations (one‑click Apply)
| Target | Configures |
|--------|-----------|
| VS Code Copilot | `overrideProxyUrl` + `debug.overrideChatEndpoint` |
| VS Code Kilo Code | `apiBase` / `apiKey` |
| VS Code OpenCode | `apiBase` / `apiKey` |
| VS Code Cline | `apiBase` / `apiKey` |
| Claude Code (VS Code) | `apiBase` / `apiKey` |
| Continue.dev | Adds `PaglaMLX` model entry (OpenAI provider) |
| Claude Code (standalone) | `customApiEndpoints.lengta` in `~/.claude.json` |
| **Claude Desktop** | `ANTHROPIC_BASE_URL` + `ANTHROPIC_API_KEY` in config |
| **OpenCode (Standalone)** | Provider block in `~/.config/opencode/opencode.json` |
| **Codex CLI** | TOML provider in `~/.codex/config.toml` |
| Agent Hermes | `apiBase` in `~/.hermes/config.json` |
| OpenClaw | `apiBase` in `~/.openclaw/config.json` |
| Qwen Code | `apiBase` in `~/.qwen/config.json` |
| OpenCode (Legacy) | `apiBase` in `~/.opencode/config.json` |

### Preflight & Safety
- **Python environment validation** — checks for `mlx_lm`, `fastapi`, `uvicorn`, `httpx`.
- **External volume detection** — if your models live on an external drive, warns before launch.
- **Port conflict detection** — checks that the gateway port isn't already in use.
- **macOS Jetsam (OOM) warning** — macOS memory pressure monitoring.

### BYOK (Bring Your Own Keys)
Manage cloud provider API keys directly in the UI:
- **Direct API:** OpenAI, Anthropic, Gemini
- **Free/Community:** OpenRouter, Groq, Together AI
- All keys are stored in UserDefaults and injected into the gateway as environment variables.

### Presets & Personas
- **Presets** — save generation parameters (temperature, top_p, top_k, min_p, max_tokens) as named profiles.
- **Personas** — save system prompts per identity with quick‑switch.
- **ChatML templates** — inject custom `chat_template` Jinja for fine‑tuned models.

---

## Requirements

- **macOS 14.0+** (Sonoma or later)
- **Apple Silicon** (M1/M2/M3/M4 — MLX requires Metal)
- **Python 3.12+** with `mlx_lm`, `fastapi`, `uvicorn`, `httpx` installed

Quick Python setup:

```bash
pip3 install mlx-lm fastapi uvicorn httpx
```

---

## Installation

### Download (easiest)
1. Download the latest `PaglaMLX.dmg` from the [Releases](https://github.com/paglagpt/PaglaMLX/releases) page.
2. Drag `PaglaMLX.app` to your Applications folder.
3. Open the app.

### Build from source

```bash
git clone https://github.com/paglagpt/PaglaMLX.git
cd PaglaMLX
./build_dmg.sh          # builds release binary + packages .app into .dmg
```

Or build and run directly:

```bash
swift build -c release && open .build/release/PaglaMLX
```

---

## Getting Started

1. **Set your Models Directory** — in Settings → App, point to a folder containing MLX model subdirectories (`.safetensors` / Hugging Face format).
2. **Check Python** — Settings → Python auto‑detects your environment. Ensure `mlx_lm` is installed.
3. **Load a model** — pick one from the menu bar model picker and press Play.
4. **Connect your clients** — any tool that speaks OpenAI or Anthropic API can now point to `http://127.0.0.1:2525/v1` (use your API key from Settings → Network).
5. **One‑click integrations** — open Settings → Integrations and hit Apply on your targets.

### Example: curl

```bash
curl http://127.0.0.1:2525/v1/chat/completions \
  -H "Authorization: Bearer $(defaults read com.lengtamlx.app apiKey)" \
  -d '{"model":"auto","messages":[{"role":"user","content":"Hello"}]}'
```

> **Tip:** Use `model=auto` to let the Auto‑Router decide, or `model=<exact name>` to hit a specific local model.

---

## API Reference

### OpenAI‑compatible endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /v1/models` | Lists loaded local models |
| `POST /v1/chat/completions` | Chat completion (OpenAI format) |
| `POST /v1/embeddings` | Embeddings (when supported by loaded model) |
| `GET /v1` | Gateway health check |

### Anthropic‑compatible endpoints

| Endpoint | Description |
|----------|-------------|
| `POST /v1/messages` | Messages API — translated to OpenAI format and back |

### Routing

The gateway inspects the `model` field in the request body:

| Model value | Routes to |
|-------------|-----------|
| `auto` | Best local model by heuristic |
| `<local model name>` | Specific loaded local model |
| `gpt‑4*`, `gpt‑3.5*`, `o1*`, `o3*` | OpenAI |
| `claude‑*` | Anthropic |
| `gemini‑*` | Gemini |
| `openrouter/*` | OpenRouter |
| `groq/*` | Groq |
| `together/*` | Together AI |
| `free` | Free Router (OpenRouter fallback) |
| anything else | Sticky session or first local model, then 503 |

---

## Architecture

```
┌─────────────┐     ┌──────────────────────────────┐
│  SwiftUI App │────▶│  RoutingGateway (Python)     │
│  (menu bar)  │     │  :2525  /v1/*                │
└──────┬───────┘     │                              │
       │             │  ┌──────┐ ┌──────┐ ┌──────┐  │
       │ loads       │  │Local │ │Cloud │ │Free  │  │
       ▼             │  │Router│ │Router│ │Router│  │
┌─────────────┐     │  └──┬───┘ └──┬───┘ └──┬───┘  │
│ mlx_lm proc │     │     │        │        │       │
│  per model   │◀────┘     ▼        ▼        ▼       │
│ port 50xx    │        local    OpenAI  OpenRouter  │
└─────────────┘        mlx_lm   Anthropic  Groq     │
                          proc    Gemini   Together │
                                                  │
┌──────────────────────┐  routes.json              │
│ IntegrationManager   │  ~/.lengtamlx/routes.json │
│ patches VS Code,     │  updated live by          │
│ Claude Desktop, etc. │  ModelOrchestrator        │
└──────────────────────┘                           │
```

- **ModelOrchestrator** starts/stops `mlx_lm.server` processes and writes the route map.
- **RoutingGateway** reads the route map, dispatches requests, and handles protocol translation.
- **IntegrationManager** patches third‑party config files so they point at the gateway.
- **TunnelManager** (optional) creates a public `trycloudflare.com` tunnel for remote access.

---

## Building from Source

```bash
git clone https://github.com/paglagpt/PaglaMLX.git
cd PaglaMLX
swift build -c release
```

The `build_dmg.sh` script automates: release build → `.app` bundle creation → ad‑hoc signing → DMG packaging (with `/Applications` symlink for drag‑and‑drop install).

To open in Xcode:

```bash
open Package.swift
```

---

## Contributing

Contributions are welcome! Please open an issue to discuss changes before submitting a PR.

1. Fork the repository.
2. Create a feature branch (`git checkout -b feat/my-change`).
3. Commit your changes (`git commit -am 'Add my feature'`).
4. Push the branch (`git push origin feat/my-change`).
5. Open a Pull Request.

For bug reports or feature requests, [open an issue](https://github.com/paglagpt/PaglaMLX/issues).

---

## License

MIT — see [LICENSE](LICENSE).
