# Getting Started

This guide walks you through the minimal setup: configure Python, point to your models, load one, and send your first request.

## 1. Set up Python

1. Open PaglaMLX.
2. Go to **Settings → Python**.
3. The app auto-detects your Python environment. If it doesn't find one, click **Detect** or manually enter the path to a Python 3.12+ binary that has `mlx-lm` installed.

## 2. Point to your models

1. Go to **Settings → App**.
2. Set **Models Directory** to the folder containing your MLX model subdirectories.
3. Each subdirectory should contain model weights (`.safetensors` files) and config in Hugging Face format.

Example structure:

```
~/Models/mlx/
├── Llama-3.2-3B-Instruct-4bit/
│   ├── config.json
│   ├── tokenizer.json
│   └── *.safetensors
├── Mistral-7B-Instruct-4bit/
│   ├── config.json
│   └── *.safetensors
└── Qwen2.5-Coder-7B-4bit/
    ├── config.json
    └── *.safetensors
```

## 3. Load a model

1. Click the menu-bar icon and open the model picker.
2. Select a model from the list.
3. Press **Play** (▶).

The app launches `mlx_lm.server` for the selected model and registers it in the route table. The status indicator turns green when ready.

## 4. Send a request

With a model running, you can call the gateway like any OpenAI-compatible API:

```bash
curl http://127.0.0.1:2525/v1/chat/completions \
  -H "Authorization: Bearer sk-mlx-<your-key>" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "auto",
    "messages": [
      {"role": "user", "content": "Hello! What can you do?"}
    ]
  }'
```

Your API key is shown in **Settings → Network**. You can rotate it with the **Regenerate** button.

## 5. Auto-configure your editor

1. Go to **Settings → Integrations**.
2. Find your editor or tool in the list.
3. Click **Apply**.

The integration manager patches the configuration file so your tool points to `http://127.0.0.1:2525/v1` automatically.
