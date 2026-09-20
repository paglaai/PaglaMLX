# Native Architecture

PaglaMLX v1.6.0 is a native macOS inference runtime for Apple Silicon. The menu-bar application, command-line interface, Swift-NIO HTTP server, routing core, scheduler, credential policy, and model engine share a headless Swift core. MLX-specific work crosses a narrow C-compatible boundary into the MLX C++ runtime.

## Request path

```text
OpenAI / Anthropic client
          │
          ▼
Swift-NIO HTTP server (:2525/v1)
          │
          ▼
Request validation + bearer-token policy
          │
          ▼
Protocol normalization and route selection
          │
          ├── local model → EnginePool → MLX C++ FFI
          └── cloud provider → provider adapter
```

There is no Python gateway, Uvicorn process, or HTTP hop between the server and the engine.

## Runtime boundaries

### SwiftUI application

The menu-bar application owns user interaction, model selection, settings, integrations, activity views, and lifecycle controls. It starts or stops the shared core but does not duplicate routing logic.

### Headless Swift core

The shared core owns the HTTP server, request lifecycle, route selection, session stickiness, local model pool, cloud provider dispatch, protocol translation, and failure policy. The CLI can host the same server without the UI.

### Swift-NIO HTTP server

The server listens on `127.0.0.1:2525` by default and exposes OpenAI-compatible `/v1/chat/completions`, `/v1/models`, and `/v1/embeddings` routes together with Anthropic-compatible `/v1/messages` translation. Bind and authentication settings are explicit so local access remains the safe default.

### EnginePool and MLX bridge

`EnginePool` owns loaded model instances and their lifecycle. Swift-facing code uses stable value types and explicit ownership. MLX-specific operations cross `MLXBridge.h` through a C-compatible ABI into the C++ implementation. C++ exceptions and failures are converted into Swift errors at the boundary.

### Provider adapters

Cloud routing is selected by the model prefix or explicit route configuration. Provider adapters own request shaping, authentication headers, response normalization, and redacted error handling. Provider credentials never enter the request log.

## Credentials and configuration

`KeychainStore` stores API keys and bearer tokens as macOS Keychain generic-password items. Non-secret preferences may remain in the configuration layer or `UserDefaults`, but secrets do not.

On first startup after upgrading, `CredentialMigration` reads known legacy values from `UserDefaults`, writes them to Keychain if absent, and deletes the legacy value only after a successful write. The migration is idempotent and retains the legacy value when Keychain access fails.

## Port strategy

The public local endpoint is `127.0.0.1:2525/v1`. The engine does not require per-model HTTP ports: model instances are managed inside the shared runtime. This removes the old process-per-model and gateway-hop topology while keeping the client-facing API stable.

## Failure policy

- Invalid requests receive structured 4xx responses.
- Missing or invalid bearer tokens are rejected before provider dispatch.
- A failed local model load marks that engine unavailable without taking down the server.
- Provider failures are normalized and redacted before reaching clients or logs.
- Keychain migration uses write-before-delete so a failed write cannot destroy a legacy credential.
- Shutdown cancels in-flight work, closes the NIO channel, and releases engine resources.

## Observability and privacy

Logs may contain route names, status codes, and durations, but must not contain prompts, generated content, bearer tokens, provider API keys, or full provider responses. Token accounting, request latency, provider cost, and durable audit logging remain roadmap items.

## Testing boundaries

HTTP route tests should exercise the server with an in-memory engine or mock provider. MLX bridge tests should validate ABI conversion and error mapping independently. Keychain tests should use an isolated service/account namespace and verify the migration invariant: a `UserDefaults` secret is removed only after its Keychain write succeeds.

## Version and references

This page documents **PaglaMLX v1.6.0**. See the [project roadmap](https://github.com/paglaai/PaglaMLX/blob/main/ROADMAP.md), [source repository](https://github.com/paglaai/PaglaMLX), and [v1.6.0 release](https://github.com/paglaai/PaglaMLX/releases/tag/v1.6.0) for the current implementation and planned work.
