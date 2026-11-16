# Runtime Architecture

PaglaMLX v1.6.0 is a native macOS application that orchestrates a Python-backed local inference runtime on Apple Silicon. Swift owns the menu-bar UI, settings, integrations, process lifecycle, and local configuration. Python processes provide model serving and protocol translation.

## Request path

```text
OpenAI / Anthropic client
          │
          ▼
Swift-managed FastAPI / Uvicorn gateway (:2525/v1)
          │
          ▼
Request validation + bearer-token policy
          │
          ▼
Protocol normalization and route selection
          │
          ├── local model → mlx_lm.server process
          └── cloud provider → provider adapter
```

The shipped runtime includes a Python gateway, Uvicorn process, and HTTP hop between the gateway and each model server.

## Runtime boundaries

### SwiftUI application

The menu-bar application owns user interaction, model selection, settings, integrations, activity views, and lifecycle controls. It starts or stops the shared core but does not duplicate routing logic.

### Swift orchestration layer

The Swift layer owns the process lifecycle, route configuration, session settings, integrations, and failure handling. It starts and monitors the Python gateway and model processes.

### FastAPI/Uvicorn gateway

The gateway listens on `127.0.0.1:2525` by default and exposes OpenAI-compatible `/v1/chat/completions`, `/v1/models`, and `/v1/embeddings` routes together with Anthropic-compatible `/v1/messages` translation. Bind and authentication settings are explicit so local access remains the safe default.

### ModelOrchestrator and model servers

`ModelOrchestrator` launches and monitors one `mlx_lm.server` process per selected model, assigns model ports, and updates the route table. Python owns the current model-serving process; Swift owns its lifecycle.

### Provider adapters

Cloud routing is selected by the model prefix or explicit route configuration. Provider adapters own request shaping, authentication headers, response normalization, and redacted error handling. Provider credentials never enter the request log.

## Credentials and configuration

`KeychainStore` stores API keys and bearer tokens as macOS Keychain generic-password items. Non-secret preferences may remain in the configuration layer or `UserDefaults`, but secrets do not.

On first startup after upgrading, `CredentialMigration` reads known legacy values from `UserDefaults`, writes them to Keychain if absent, and deletes the legacy value only after a successful write. The migration is idempotent and retains the legacy value when Keychain access fails.

## Port strategy

The public local endpoint is `127.0.0.1:2525/v1`. Each local `mlx_lm.server` process receives its own model port, typically in the 5000 range. The gateway remains the stable client-facing endpoint and dispatches between those model ports and cloud providers.

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

HTTP route tests should exercise the gateway with a mock provider or test model process. Process lifecycle tests should cover startup, route registration, shutdown, and failed Python dependencies. Keychain tests should use an isolated service/account namespace and verify the migration invariant: a `UserDefaults` secret is removed only after its Keychain write succeeds.

## Version and references

This page documents **PaglaMLX v1.6.0**. The native Swift + MLX C++ FFI runtime described in the roadmap is a future migration target; it is not the shipped runtime. See the [project roadmap](https://github.com/paglaai/PaglaMLX/blob/main/ROADMAP.md), [source repository](https://github.com/paglaai/PaglaMLX), and [v1.6.0 release](https://github.com/paglaai/PaglaMLX/releases/tag/v1.6.0) for current implementation and planned work.
