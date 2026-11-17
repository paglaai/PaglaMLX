<p align="center">
  <strong>PAGLA / MLX</strong>
</p>

<p align="center">
  <sub>LOCAL LLM ORCHESTRATION &nbsp;·&nbsp; APPLE SILICON &nbsp;·&nbsp; MENU-BAR CONTROL</sub>
</p>

<p align="center">
  <a href="https://paglaai.github.io/PaglaMLX/">DOCUMENTATION</a>
  &nbsp;·&nbsp;
  <a href="https://paglaai.github.io/PaglaMLX/api-reference.html">API REFERENCE</a>
  &nbsp;·&nbsp;
  <a href="https://github.com/paglaai/PaglaMLX/releases">RELEASES</a>
  &nbsp;·&nbsp;
  <a href="https://github.com/paglaai/PaglaMLX/issues">ISSUES</a>
</p>

---

> **PaglaMLX** is a native macOS application for orchestrating MLX-compatible language models on Apple Silicon. Swift owns the menu-bar experience and process lifecycle; Python provides the current `mlx_lm.server` model processes and FastAPI/Uvicorn gateway proxies.

```text
PAGLAMLX  /  v1.6.0  /  STABLE

LOCAL ENDPOINT       127.0.0.1:2525/v1
PLATFORM             macOS 14+ · Apple Silicon
MODEL RUNTIME        mlx_lm.server
GATEWAY              FastAPI + Uvicorn
CREDENTIALS          macOS Keychain
```

## 01 / What it does

PaglaMLX gives local models one stable, OpenAI- and Anthropic-compatible endpoint. Load models from the menu bar, route requests by model name or intent, connect developer tools, and fall back to cloud providers when needed.

- Load and unload multiple MLX models from a single menu-bar application.
- Route `model=auto` requests using capability, context, and intent signals.
- Translate Anthropic `/v1/messages` requests to and from OpenAI-compatible shapes.
- Dispatch cloud requests by provider prefix.
- Apply integrations for editors, coding agents, and desktop clients.
- Store provider keys and bearer tokens in macOS Keychain.
- Keep session requests sticky to the selected backend.

## 02 / Install

### Download the app

Download the latest `.dmg` from [GitHub Releases](https://github.com/paglaai/PaglaMLX/releases), open it, and drag `PaglaMLX.app` to `Applications`.

### Runtime requirements

| Requirement | Version / value |
|---|---|
| Operating system | macOS 14.0+ |
| Hardware | Apple Silicon: M1, M2, M3, or M4 |
| Python | 3.12+ |
| Model serving | `mlx-lm` |
| Gateway packages | `fastapi`, `uvicorn`, `httpx` |

Install the Python runtime dependencies before launching the app:

```bash
pip3 install mlx-lm fastapi uvicorn httpx
```

### Build from source

```bash
git clone https://github.com/paglaai/PaglaMLX.git
cd PaglaMLX
./build_dmg.sh
```

Or build the Swift package directly:

```bash
swift build -c release
```

## 03 / First run

1. Open **Settings → App** and choose the directory containing your MLX model folders.
2. Open **Settings → Python** and confirm the Python 3.12+ executable.
3. Run the preflight checks and resolve any missing package or permission warnings.
4. Choose a model from the menu-bar picker and press **Play**.
5. Connect a compatible client to `http://127.0.0.1:2525/v1`.

A model directory typically looks like this:

```text
~/Models/mlx/
├── Llama-3.2-3B-Instruct-4bit/
│   ├── config.json
│   ├── tokenizer.json
│   └── *.safetensors
├── Mistral-7B-Instruct-4bit/
│   └── ...
└── Qwen2.5-Coder-7B-4bit/
    └── ...
```

## 04 / Request surface

### OpenAI-compatible

```bash
curl http://127.0.0.1:2525/v1/chat/completions \
  -H "Authorization: Bearer <your-key>" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "auto",
    "messages": [
      {"role": "user", "content": "Hello from PaglaMLX."}
    ]
  }'
```

### Anthropic-compatible

```bash
curl http://127.0.0.1:2525/v1/messages \
  -H "x-api-key: <your-key>" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "auto",
    "max_tokens": 512,
    "messages": [
      {"role": "user", "content": "Hello from Claude-compatible tooling."}
    ]
  }'
```

The local bearer token is configured in **Settings → Network**. Current credentials are stored in Keychain; do not use `defaults read` to retrieve secrets.

## 05 / Routing logic

```text
01  EXACT LOCAL MATCH       model name matches a loaded route
02  AUTO-ROUTER             capability + context + request intent
03  CLOUD PREFIX            provider-specific model prefixes
04  FREE ROUTER             optional OpenRouter fallback
05  SESSION STICKINESS      reuse the session's selected backend
06  LOCAL FALLBACK          first available local model
07  HTTP 503                no usable route exists
```

| Prefix | Provider |
|---|---|
| `gpt-`, `o1`, `o3` | OpenAI |
| `claude-` | Anthropic |
| `gemini-` | Gemini |
| `openrouter/` | OpenRouter |
| `groq/` | Groq |
| `together/` | Together AI |

## 06 / Client integrations

PaglaMLX can apply endpoint and credential settings for common local-AI clients:

- VS Code, Copilot, Cline, Kilo Code, and Continue.dev
- Claude Desktop and Claude Code
- OpenCode and Codex CLI
- Agent Hermes, OpenClaw, and Qwen Code

Open **Settings → Integrations**, select a client, review the target configuration, and choose **Apply**.

## 07 / Runtime architecture

```text
┌──────────────────────┐
│  SwiftUI menu bar    │  settings · integrations · lifecycle
└──────────┬───────────┘
           │ manages
           ▼
┌──────────────────────┐
│  Swift orchestration │  route table · preflight · processes
└──────────┬───────────┘
           │ starts / monitors
           ▼
┌──────────────────────┐       ┌──────────────────────────┐
│ FastAPI / Uvicorn    │──────▶│ mlx_lm.server            │
│ 127.0.0.1:2525/v1    │       │ one process per model    │
└──────────┬───────────┘       │ ports 50xx               │
           │                   └──────────────────────────┘
           ├──────────────▶ OpenAI / Anthropic / Gemini
           ├──────────────▶ OpenRouter / Groq / Together
           └──────────────▶ Free Router fallback
```

The current shipped release uses Swift-managed Python processes. A future native Swift + MLX C++ FFI runtime is documented in the [architecture reference](docs/architecture.md) and tracked in the [roadmap](ROADMAP.md); it is not yet the production runtime.

## 08 / Security baseline

- Bind locally to `127.0.0.1` by default.
- Keep API keys and bearer tokens in macOS Keychain.
- Migrate legacy `UserDefaults` credentials with write-before-delete safety.
- Do not log prompts, generated content, provider responses, or credentials.
- Treat non-loopback binding and public tunnels as explicit security decisions.

Read the [security policy](SECURITY.md) before reporting a vulnerability.

## 09 / Documentation map

| Document | Purpose |
|---|---|
| [Getting started](docs/docs/getting-started.md) | Install, configure, load, and call a model |
| [Runtime architecture](docs/docs/architecture.md) | Current process boundaries and request flow |
| [Building](docs/docs/building.md) | Build the app and DMG from source |
| [API reference](https://paglaai.github.io/PaglaMLX/api-reference.html) | Endpoint shapes and examples |
| [Roadmap](ROADMAP.md) | Current priorities and future native migration |
| [Roadmap](ROADMAP.md) | Changes between runtime generations and future native migration |
| [Security policy](SECURITY.md) | Responsible disclosure and credential handling |

## 10 / Contributing

Contributions are welcome. Before opening a pull request:

1. Read the relevant architecture and build documentation.
2. Keep secrets out of source, logs, screenshots, and commits.
3. Add or update tests for behavior changes.
4. Open an issue first for substantial architectural changes.

Report bugs and request features through [GitHub Issues](https://github.com/paglaai/PaglaMLX/issues).

## 11 / License

MIT — see [LICENSE](LICENSE).

---

<p align="center">
  <sub>PAGLA / MLX &nbsp;·&nbsp; LOCAL FIRST &nbsp;·&nbsp; APPLE SILICON</sub>
</p>
