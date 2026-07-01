# Presets & Personas

## Presets

Presets save generation parameters as named profiles for quick switching.

| Parameter    | Default | Description                           |
|-------------|---------|---------------------------------------|
| Temperature | 0.0     | Randomness (0 = deterministic)        |
| Top P       | 1.0     | Nucleus sampling threshold            |
| Top K       | 0       | Top-K sampling (0 = disabled)         |
| Min P       | 0.0     | Minimum probability threshold         |
| Max Tokens  | 512     | Maximum tokens in the response        |
| Chat Template | (empty) | Custom ChatML template (Jinja)     |

### Built-in presets

- **Creative** — `temp: 0.8, top_p: 0.9, top_k: 40` — more varied outputs.
- **Precise** — `temp: 0.2, top_p: 1.0` — focused, deterministic responses.
- **ChatML Enforced** — forces the ChatML template for models that expect it.

### ChatML templates

Some fine-tuned models require a specific chat template. The **ChatML Enforced** preset injects the standard `<|im_start|>` / `<|im_end|>` format. You can add custom templates for other models.

## Personas

Personas store a name + system prompt combination for different use cases.

| Persona       | System prompt                                                    |
|---------------|------------------------------------------------------------------|
| Default       | `You are a helpful AI assistant.`                                |

Add more personas for coding, creative writing, roleplay, or any recurring scenario. Switch between them instantly from the UI.
