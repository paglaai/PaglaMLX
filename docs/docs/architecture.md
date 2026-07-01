# Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   PaglaMLX App (SwiftUI)                    │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │ Model        │  │ Preflight    │  │ Settings          │   │
│  │ Orchestrator │  │ Runner       │  │ Manager           │   │
│  └──────┬───────┘  └──────────────┘  └────────┬─────────┘   │
│         │                                     │              │
│         ▼                                     ▼              │
│  ┌──────────────┐                     ┌──────────────────┐   │
│  │ mlx_lm proc  │                     │ Integration      │   │
│  │ per model    │                     │ Manager          │   │
│  │ port 50xx    │                     └────────┬─────────┘   │
│  └──────┬───────┘                              │              │
│         │                                      │              │
└─────────┼──────────────────────────────────────┼──────────────┘
          │                                      │
          ▼                                      ▼
┌─────────────────────┐          ┌───────────────────────────┐
│ routes.json          │          │ Third-party config files  │
│ ~/.lengtamlx/        │          │ VS Code, Claude Desktop,  │
│ (live route table)   │          │ OpenCode, Codex, ...      │
└──────────┬───────────┘          └───────────────────────────┘
           │
           ▼
┌───────────────────────────────────────────────────────────┐
│              Routing Gateway (Python / FastAPI)            │
│                                                           │
│  Port 2525                                                │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │ OpenAI   │  │ Anthropic│  │ Auto     │  │ Session  │  │
│  │ Handler  │  │ Translate│  │ Router   │  │ Sticky   │  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └──────────┘  │
│       │             │             │                        │
│       └─────────────┴─────────────┘                        │
│                      │                                     │
│                      ▼                                     │
│           ┌────────────────────┐                           │
│           │   Dispatch Layer   │                           │
│           │   (local / cloud)  │                           │
│           └────────────────────┘                           │
└───────────────────────────────────────────────────────────┘
           │                │                  │
           ▼                ▼                  ▼
   ┌────────────┐   ┌────────────┐    ┌──────────────┐
   │ local mlx  │   │  OpenAI /  │    │  OpenRouter  │
   │ processes  │   │ Anthropic  │    │  Groq /      │
   │ (port 5xxx)│   │  Gemini    │    │  Together    │
   └────────────┘   └────────────┘    └──────────────┘
```

## Components

### ModelOrchestrator
Manages the lifecycle of `mlx_lm.server` processes. When you load a model, it:
1. Assigns a port number.
2. Launches `mlx_lm.server --model <path> --port <port>`.
3. Writes the route mapping to `routes.json`.
4. Monitors the process and cleans up on exit.

### RoutingGateway
A Python FastAPI server that proxies all API requests. It:
- Speaks OpenAI format natively (`/v1/chat/completions`).
- Translates Anthropic `/v1/messages` bidirectionally.
- Reads `routes.json` for local model dispatch.
- Handles prefix-based cloud routing, Free Router, and session stickiness.
- Enforces optional Bearer-token authentication.

### IntegrationManager
Patches third-party configuration files so they point to the gateway. Each integration target has a type that determines how the config is modified.

### SettingsManager
Singleton observable object persisting all user preferences to UserDefaults.

### PreflightRunner
Runs validation checks before the server starts: Python availability, model directory integrity, port availability, external volume mounting.

### TunnelManager
Creates a Cloudflare Tunnel (`trycloudflare.com`) for remote access to the gateway.
