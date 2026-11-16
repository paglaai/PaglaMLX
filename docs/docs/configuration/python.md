# Runtime Configuration

PaglaMLX v1.6.0 uses Swift for macOS orchestration and Python for model serving and gateway translation. Python is required at runtime.

## Runtime path

The current request path is:

```text
Client → FastAPI/Uvicorn gateway → mlx_lm.server process → Apple Silicon GPU
```

The default local endpoint is `http://127.0.0.1:2525/v1`.

## Model directory

Configure the directory containing MLX-compatible model subdirectories in **Settings → App**. PaglaMLX discovers model weights and configuration files, then asks `mlx_lm.server` to load the selected model.

## Build-time toolchain

When building from source, use Xcode 15+ or Swift 5.9+ on macOS 14.0+ and Apple Silicon. Also install the Python runtime dependencies:

```bash
pip3 install mlx-lm fastapi uvicorn httpx
swift build -c release
```

Install the current runtime dependencies with `pip3 install mlx-lm fastapi uvicorn httpx`, then configure the detected Python binary in **Settings → Python**. The app uses that executable to launch `mlx_lm.server` and the gateway proxies.

## Runtime status

| Status | Meaning |
|---|---|
| **Ready** | Gateway and model process are available. |
| **Loading** | The selected `mlx_lm.server` process is starting. |
| **Unavailable** | Check the model directory, Metal support, and application logs. |

## Migration from v1.x

Older releases stored provider credentials or bearer tokens in `UserDefaults`. v1.6.0 migrates known legacy keys to macOS Keychain on startup. The migration is idempotent and preserves the legacy value if the Keychain write fails.

## Related pages

- [Network configuration](network)
- [Cloud provider credentials](cloud-byok)
- [Architecture](../architecture)
- [Building from source](../building)
