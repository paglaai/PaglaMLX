# Routing

The gateway dispatches requests based on the `model` field. This page documents the full routing logic.

## Evaluation order

When a request arrives, the gateway checks the following in order:

### 1. Local exact match

If the model name is an exact key in `routes.json` (`~/.lengtamlx/routes.json`), the request is forwarded to the corresponding local `mlx_lm.server` process.

### 2. Auto-Router (`model=auto`)

When `model=auto` is requested, the gateway runs a heuristic engine to pick the best running local model:

| Factor                 | Weight | Description                                     |
|------------------------|--------|-------------------------------------------------|
| **Multimodal**         | +1000  | Image requests must go to a VLM (`modelType=VLM`) — non-VLM models are skipped entirely |
| **Context fit**        | +50    | Estimated prompt tokens >50% of model context — snug fit preferred |
|                        | +30    | Estimated tokens 20–50% of context — good fit   |
|                        | +10    | Estimated tokens under 20% — works but overkill |
| **Token overflow**     | skip   | Estimated tokens exceed context length — model cannot fit the prompt |
| **Keyword intent**     | +20    | Code/math keywords detected — prefer capable models for technical work |
|                        | +15    | Reasoning keywords detected                     |

The model with the highest score is selected. If no running model fits (e.g., image request but no VLM running), the gateway logs available VLM models on disk and falls through to the default fallback.

### 3. Prefix-based cloud routing

| Model prefix        | Routes to       | Requires key           |
|---------------------|-----------------|------------------------|
| `gpt-`, `o1`, `o3` | OpenAI          | `OPENAI_KEY`           |
| `claude-`          | Anthropic       | `ANTHROPIC_KEY`        |
| `gemini-`          | Gemini          | `GEMINI_KEY`           |
| `openrouter/`      | OpenRouter      | `OPENROUTER_KEY`       |
| `free`             | OpenRouter auto | `FREE_ROUTER_KEY`      |

### 4. Session stickiness

The gateway tracks session IDs (from `x-session-id` or `authorization` header). If the current request's session has been routed before, it reuses the previous backend.

### 5. Local default fallback

If no match, the request is forwarded to the first available running local model.

### 6. 503

If none of the above applies, the gateway returns HTTP 503.

## Token estimation

The auto-router estimates prompt token count at ~4 characters per token. Image content is estimated at ~1000 tokens per image. This is a rough heuristic — the model's `max_position_embeddings` from `config.json` is used as the context limit.

## Intent detection

The gateway scans message text for keyword patterns:

- **Technical** (code/math): `code`, `function`, `implement`, `debug`, `solve`, `equation`, `calculate`, etc.
- **Reasoning**: `explain`, `reason`, `analyze`, `compare`, `think step by step`, etc.
- **General**: none of the above

## Session stickiness

Each request is tagged with a session ID. Once a route is determined, the base URL and auth header are cached per session. Subsequent requests from the same session reuse the same backend, ensuring consistent behavior across multi-turn conversations.
