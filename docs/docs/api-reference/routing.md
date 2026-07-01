# Routing

The gateway dispatches requests based on the `model` field. This page documents the full routing logic.

## Evaluation order

When a request arrives, the gateway checks the following in order:

### 1. Local exact match

If the model name is an exact key in `routes.json` (`~/.lengtamlx/routes.json`), the request is forwarded to the corresponding local `mlx_lm.server` process.

### 2. Local substring match

If no exact match, the gateway checks whether the model name contains (or is contained in) any local route key (case-insensitive).

### 3. Prefix-based cloud routing

| Model prefix        | Routes to       | Requires key           |
|---------------------|-----------------|------------------------|
| `gpt-`, `o1`, `o3` | OpenAI          | `OPENAI_KEY`           |
| `claude-`          | Anthropic       | `ANTHROPIC_KEY`        |
| `gemini-`          | Gemini          | `GEMINI_KEY`           |
| `openrouter/`      | OpenRouter      | `OPENROUTER_KEY`       |
| `groq/`            | Groq            | `GROQ_KEY`             |
| `together/`        | Together AI     | `TOGETHER_KEY`         |

### 4. Free Router

If the Free Router is enabled (Settings → Cloud) and no match is found, the request is forwarded to OpenRouter.

### 5. Session stickiness

The gateway tracks session IDs (from `x-session-id` or `authorization` header). If the current request's session has been routed before, it reuses the previous backend.

### 6. Local default fallback

If routes exist but no match, the request is forwarded to the first available local model.

### 7. 503

If none of the above applies, the gateway returns HTTP 503.

## Auto-Router (`model=auto`)

When `model=auto` is requested, the Auto-Router heuristic selects the best local model:

1. **Multimodal** — prefer models with vision capabilities (`vl`, `vision` in name).
2. **Long context** — prefer models with larger context windows.
3. **Keyword intent** — detect code (`coder`, `code`) or math (`reason`, `math`) models.
4. **Default** — fall back to the model tagged as default in Settings.

## Session stickiness

Each request is tagged with a session ID. Once a route is determined, the base URL and auth header are cached per session. Subsequent requests from the same session reuse the same backend, ensuring consistent behavior across multi-turn conversations.
