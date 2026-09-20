# Troubleshooting
## Model returns 404 or “Repository Not Found”

**Cause:** The requested model identifier does not match a loaded local model or configured cloud route.

**Solution:** Use the gateway at `:2525/v1` and pass `model=auto`, or select the exact model name shown in the menu-bar picker. Confirm that the model directory contains its configuration and weight files.

## Model directory is not detected

Set the directory in **Settings → App** and verify that it contains MLX-compatible subdirectories with `config.json` and `.safetensors` files. Grant PaglaMLX access to the directory when macOS prompts.

## Port already in use

Stop the process using port 2525 (`lsof -ti:2525 | xargs kill`) or change the port in **Settings → Network**.

## Model loads but returns 503

Use `model=auto`, confirm that the model is listed as loaded, and reload it if the native engine reported an error. Also verify that macOS permits access to the model directory and Metal resources.

## Cloud routing not working

Ensure the provider API key is configured in **Settings → Cloud**, is valid, has quota, and that the provider prefix and model name are correct. Keys are stored in macOS Keychain; do not paste them into logs or issue reports.

## Claude Desktop reports no compatible models

Make sure a local model is loaded, enable Developer Mode if required by your client version, and verify the base URL is `http://127.0.0.1:2525/v1` with the current bearer token.

## Integrations are not persisting

Click **Apply** again after updating settings. The integration manager rewrites the client configuration with the current local endpoint and token.

## macOS reports “Operation not permitted”

Grant PaglaMLX access in **System Settings → Privacy & Security**, including Files and Folders and any required network permissions.

## Out of memory or Jetsam termination

Reduce `max_tokens`, load a smaller or more aggressively quantized model, close other memory-intensive applications, and monitor memory pressure in Activity Monitor.

## Credential migration did not complete

The migration is safe to retry. v1.6.0 writes each legacy credential to Keychain before deleting the corresponding `UserDefaults` value. If Keychain access is unavailable, the legacy value is retained and the error is reported without printing the secret.

## Gateway crashes on startup

The v1.6.0 gateway is native Swift and does not depend on Python, FastAPI, Uvicorn, or `mlx_lm.server`. Check the application logs, verify the configured port, confirm Apple Silicon and macOS 14.0+ requirements, and restart the app.

## References

- [Architecture reference](architecture)
- [Roadmap](https://github.com/paglaai/PaglaMLX/blob/main/ROADMAP.md)
- [v1.6.0 release](https://github.com/paglaai/PaglaMLX/releases/tag/v1.6.0)
