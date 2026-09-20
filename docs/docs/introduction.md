# PaglaMLX v1.6.0

**Native local LLM orchestration for Apple Silicon.**

PaglaMLX is a native macOS application that orchestrates and serves MLX-compatible language models locally on Apple Silicon. The Swift runtime combines the menu-bar application, HTTP server, scheduler, and model engine in one process, with a narrow C-compatible bridge into the MLX C++ runtime. Its local gateway at `127.0.0.1:2525/v1` speaks both OpenAI and Anthropic API formats without a Python sidecar.

## Key capabilities

- **One-click model loading** — scan a directory of MLX models, pick one, and press Play.
- **Native Swift gateway** — a single endpoint at `http://127.0.0.1:2525/v1` speaks OpenAI and Anthropic API formats.
- **Smart routing** — prefix-based dispatch (`gpt-` → OpenAI, `claude-` → Anthropic, `gemini-` → Gemini, `openrouter/*`, `groq/*`, `together/*`) plus an Auto-Router for `model=auto`.
- **14 integration targets** — one-click Apply for VS Code extensions, Claude Desktop, OpenCode, Codex CLI, Continue.dev, and more.
- **Secure BYOK storage** — provider API keys and bearer tokens are stored in macOS Keychain; legacy UserDefaults credentials migrate with write-before-delete safety.
- **Session stickiness** — once routed, requests from the same session stay on the same backend.
- **Protocol translation** — Claude Desktop can talk to local models through bidirectional Anthropic-to-OpenAI translation.

Intended for developers, researchers, and anyone running local LLMs on Apple Silicon who wants a seamless, GUI-driven workflow. Requires macOS 14.0+ and Apple Silicon. See the [architecture reference](architecture) for the request lifecycle, FFI boundary, port strategy, and failure modes, and the [project roadmap](https://github.com/paglaai/PaglaMLX/blob/main/ROADMAP.md) for planned improvements.

## v1.6.0 foundation

This release establishes the native Swift + C++ FFI architecture, documents the runtime boundaries, and moves credentials from `UserDefaults` into the macOS Keychain. Migration is idempotent and removes a legacy credential only after its Keychain write succeeds.

- [Read the v1.6.0 release notes](https://github.com/paglaai/PaglaMLX/releases/tag/v1.6.0)
- [Read the architecture reference](architecture)
- [Review the roadmap](https://github.com/paglaai/PaglaMLX/blob/main/ROADMAP.md)
- [Browse the source on GitHub](https://github.com/paglaai/PaglaMLX)

> **Runtime note:** Python is not required. PaglaMLX v1.6.0 uses its native Swift server and MLX bridge.

## Documentation links

- [Installation](installation)
- [Getting started](getting-started)
- [Network configuration](configuration/network)
- [Cloud provider credentials](configuration/cloud-byok)
- [API reference](api-reference/chat-completions)
- [Architecture](architecture)
- [Building from source](building)
- [Roadmap on GitHub](https://github.com/paglaai/PaglaMLX/blob/main/ROADMAP.md)

## Version

The public documentation targets **PaglaMLX v1.6.0**, the current stable release.

## Security

API keys and bearer tokens are stored by `KeychainStore` in the macOS Keychain. Migration from legacy `UserDefaults` values is one-way and idempotent: PaglaMLX writes the Keychain item first and deletes the old value only after a successful write. Never put prompts, generated content, bearer tokens, or provider API keys in logs or issue reports.

## Supported architecture

```text
SwiftUI menu bar / CLI
          │
          ▼
Swift-NIO HTTP server (:2525/v1)
          │
          ▼
Routing + EnginePool + credential policy
          │
          ▼
C-compatible MLX bridge → MLX C++ runtime
```

The native Swift server is the supported runtime architecture; the former Python gateway is not required or maintained as a compatibility target.

## Roadmap

The next priorities are route integration tests, UI snapshot tests, request coalescing, token and cost tracking, onboarding, benchmarks, streaming backpressure, model warm pools, and a plugin SDK. See the [quarter-by-quarter roadmap](https://github.com/paglaai/PaglaMLX/blob/main/ROADMAP.md) for the current plan.

## Support and contributions

Bug reports and feature requests are welcome in the [GitHub issue tracker](https://github.com/paglaai/PaglaMLX/issues). Contributions should follow the repository's [contribution guidelines](https://github.com/paglaai/PaglaMLX/blob/main/CONTRIBUTING.md).

## License

PaglaMLX is released under the [MIT License](https://github.com/paglaai/PaglaMLX/blob/main/LICENSE).
