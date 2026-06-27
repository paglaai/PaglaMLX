# PaglaMLX

PaglaMLX is a powerful, lightweight, native macOS menu-bar application for orchestrating local LLMs via `mlx_lm`, built with SwiftUI and Python. It acts as an intelligent model gateway, auto-routing API requests, handling session stickiness, and providing advanced controls for multi-model workflows.

## Features

- **Local MLX Orchestration:** Scan, load, and manage Apple Silicon optimized `mlx_lm` models visually.
- **Auto-Router & Free Router:** Intelligent reverse proxy (`http://127.0.0.1:2525/v1`) that auto-detects `gpt-`, `claude-`, and `gemini-` prefixes and seamlessly routes them to cloud providers or OpenRouter.
- **Auto-Integration:** Automatically patches VS Code (Copilot, Cline, Continue) and standalone agents to use the local proxy with a single click.
- **Personas & Presets:** Save generation parameters (Temperature, Top P, Max Tokens) and inject specific ChatML templates or System Prompts instantly.
- **Preflight & Error Handling:** Built-in safeguards against macOS Jetsam OOM kills, Python environment validation, and robust upstream HTTP error capture.
- **BYOK (Bring Your Own Keys):** Securely manage API keys for OpenAI, Anthropic, Gemini, and OpenRouter directly in the UI.

## Installation

1. Download the latest `PaglaMLX.dmg` from the Releases page.
2. Drag `PaglaMLX.app` to your Applications folder.
3. Open the app. 
4. Ensure your Python environment has `mlx_lm`, `fastapi`, `uvicorn`, and `httpx` installed.

## Usage

- Set your **Models Directory** (e.g., `~/Models/MLX`) in Settings > App.
- Set your API Keys in Settings > Cloud.
- Press **Apply** in the Integrations tab to auto-configure your IDE extensions.
- Select a model from the menu bar and press Play!

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
