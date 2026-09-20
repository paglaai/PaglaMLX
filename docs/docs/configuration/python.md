# Runtime Configuration

PaglaMLX v1.6.0 uses a native Swift runtime. The HTTP server, routing layer, model lifecycle, and MLX bridge run inside the application; Python is not required at runtime.

## Native runtime

The request path is:

```text
Client → Swift-NIO HTTP server → routing core → MLX C++ bridge → Apple Silicon GPU
```

The default local endpoint is `http://127.0.0.1:2525/v1`.

## Model directory

Configure the directory containing MLX-compatible model subdirectories in **Settings → App**. PaglaMLX discovers model weights and configuration files, then loads the selected model through the native engine.

## Build-time toolchain

When building from source, use Xcode 15+ or Swift 5.9+ on macOS 14.0+ and Apple Silicon:

```bash
swift build -c release
```

No `pip3`, `mlx-lm`, FastAPI, Uvicorn, or Python virtual environment is needed for the v1.6.0 application.

## Runtime status

| Status | Meaning |
|---|---|
| **Ready** | Native server and model engine are available. |
| **Loading** | The selected model is being loaded through the MLX bridge. |
| **Unavailable** | Check the model directory, Metal support, and application logs. |

## Migration from v1.x

Older releases stored provider credentials or bearer tokens in `UserDefaults`. v1.6.0 migrates known legacy keys to macOS Keychain on startup. The migration is idempotent and preserves the legacy value if the Keychain write fails.

## Related pages

- [Network configuration](network)
- [Cloud provider credentials](cloud-byok)
- [Architecture](../architecture)
- [Building from source](../building)
