# Getting Started

This guide walks you through the minimal v1.6.0 setup: choose your models, load one in the native Swift runtime, and send your first request.

## 1. Install PaglaMLX

Download the [v1.6.0 DMG](https://github.com/paglaai/PaglaMLX/releases/tag/v1.6.0), or [build from source](installation). Python is not required.

## 2. Point to your models

1. Open PaglaMLX from the macOS menu bar.
2. Go to **Settings → App**.
3. Set **Models Directory** to the folder containing your MLX model subdirectories.
4. Each subdirectory should contain model weights (`.safetensors` files) and configuration in Hugging Face format.

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
3. Press **Play**.

The native Swift engine loads the selected model through the MLX C++ bridge and registers it in the route table. The status indicator turns green when it is ready.

## 4. Send a request

With a model running, call the local Swift-NIO gateway like any OpenAI-compatible API:

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

Your bearer token is shown in **Settings → Network**. API keys and bearer tokens are stored securely in macOS Keychain. You can rotate the local token with the **Regenerate** button.

## 5. Auto-configure your editor

1. Go to **Settings → Integrations**.
2. Find your editor or tool in the list.
3. Click **Apply**.

The integration manager patches the configuration file so your tool points to `http://127.0.0.1:2525/v1` automatically.

## 6. Read the design and roadmap

- Read the [native architecture reference](architecture) for the request lifecycle and FFI boundary.
- Review the [v1.6.0 roadmap](https://github.com/paglaai/PaglaMLX/blob/main/ROADMAP.md) for upcoming work.

## Version

This guide targets **PaglaMLX v1.6.0**.
