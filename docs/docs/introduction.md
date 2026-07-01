# PaglaMLX

**Local LLM orchestration for Apple Silicon.**

PaglaMLX is a native macOS menu-bar application that manages and serves MLX-compatible language models through a smart reverse proxy. No command line needed.

## Key capabilities

- **One-click model loading** — scan a directory of MLX models, pick one, and press Play. Each model runs as an isolated `mlx_lm.server` process.
- **Unified gateway** — a single endpoint at `http://127.0.0.1:2525/v1` speaks both OpenAI and Anthropic API formats natively.
- **Smart routing** — prefix-based dispatch (`gpt-` → OpenAI, `claude-` → Anthropic, `gemini-` → Gemini, `openrouter/*`, `groq/*`, `together/*`) plus an Auto-Router that picks the best local model when you pass `model=auto`.
- **14 integration targets** — one-click Apply to wire up VS Code extensions, Claude Desktop, OpenCode, Codex CLI, Continue.dev, and more.
- **BYOK (Bring Your Own Keys)** — manage cloud provider API keys directly in the UI.
- **Session stickiness** — once routed, all requests from the same session stay on the same backend.
- **Protocol translation** — Claude Desktop can talk to local models via bidirectional Anthropic-to-OpenAI translation.

Intended for developers, researchers, and anyone running local LLMs on Apple Silicon who wants a seamless, GUI-driven workflow. Requires macOS 14.0+ and Python 3.12+ with `mlx-lm` installed.
