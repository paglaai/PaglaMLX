# Cloud & BYOK

The Cloud tab manages API keys for external providers and controls the Free Router.

## Direct API providers

These providers are routed by prefix when the model name starts with a known keyword:

| Provider   | Prefix       | Key field     | Endpoint                               |
|------------|--------------|---------------|----------------------------------------|
| OpenAI     | `gpt-`, `o1`, `o3` | OpenAI Key    | `https://api.openai.com/v1/`           |
| Anthropic  | `claude-`    | Anthropic Key | `https://api.anthropic.com/v1/`        |
| Gemini     | `gemini-`    | Gemini Key    | `https://generativelanguage.googleapis.com/v1beta/openai/` |

## Free & Community providers

These are useful for cost-effective fallback, prototyping, or accessing open models:

| Provider     | Prefix         | Key field    | Endpoint                              |
|--------------|----------------|--------------|---------------------------------------|
| OpenRouter   | `openrouter/`  | OpenRouter Key | `https://openrouter.ai/api/v1/`     |
| Groq         | `groq/`        | Groq Key     | `https://api.groq.com/openai/v1/`    |
| Together AI  | `together/`    | Together Key | `https://api.together.xyz/v1/`       |

## Free Router

Toggle **Free Router** to route unrecognized model names through OpenRouter as a fallback. This is useful when you want to try any model without adding it explicitly.

```
Free Router OFF → unrecognized models → 503
Free Router ON  → unrecognized models → OpenRouter
```

## How routing works

The gateway evaluates requests in this order:

1. **Exact local match** — if the model name matches a loaded local model, forward locally.
2. **Substring match** — fuzzy match against loaded local model names.
3. **Prefix-based external** — check prefixes in order (OpenAI, Anthropic, Gemini, OpenRouter, Groq, Together).
4. **Free router** — if enabled and no match yet, forward to OpenRouter.
5. **Session stickiness** — if previously routed, reuse the same backend.
6. **Local default** — forward to the first available local model.
7. **503** — no route available.
