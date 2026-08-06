# Troubleshooting

## Model returns 404 / "Repository Not Found"

**Symptom**: Requests to a running local model return `{"error": "Repository Not Found for url: https://huggingface.co/api/models/..."}`

**Cause**: `mlx_lm.server` interprets the `model` field in your request body as a HuggingFace repo ID. If the name doesn't match the loaded model, it tries to fetch from HuggingFace.

**Solution**: Use the gateway at `:2525/v1` instead of connecting directly to the model's port. The gateway automatically sets the correct model identifier. Alternatively, set `"model": "default_model"` in your request body when targeting a model server directly.

## HF Cache not found

**Symptom**: Model process crashes after loading with `CacheNotFound` error.

**Cause**: `mlx_lm.server` needs a HuggingFace Hub cache directory. If your models are on an external volume, the default cache path may not exist.

**Solution**: Set the `HF_HUB_CACHE` environment variable before launching PaglaMLX, or the app will set it automatically based on your models directory parent.

## Python not found

**Symptom**: Preflight reports "No valid Python executable found."

**Solution**: Install Python 3.12+ with the required packages:

```bash
pip3 install mlx-lm fastapi uvicorn httpx
```

If Python is installed but not detected, set the path manually in **Settings → Python**.

## Port already in use

**Symptom**: Preflight reports "Port 2525 is already in use."

**Solution**: Either stop the process using port 2525 (`lsof -ti:2525 | xargs kill`) or change the port in **Settings → Network**.

## Model loads but returns 503

**Symptom**: `curl` requests return HTTP 503.

**Causes**:
- The model name in your request doesn't match any loaded model — use `model=auto` to let the router pick.
- The model process crashed — check the console logs and reload the model.
- The route table hasn't updated — toggle the model off and back on.

## Cloud routing not working

**Symptom**: `gpt-4` prefix returns an error.

**Solutions**:
- Ensure the corresponding API key is set in **Settings → Cloud**.
- Check the key is valid and has quota available.
- Verify the gateway has network access (not blocked by firewall/proxy).

## Claude Desktop "no compatible models"

**Symptom**: Claude Desktop shows "No compatible models available" after configuring.

**Solutions**:
- Make sure at least one local model is loaded before opening Claude Desktop.
- Claude Desktop requires Developer Mode (Settings → Developer → Enable Developer Mode).
- Verify `ANTHROPIC_BASE_URL` and `ANTHROPIC_API_KEY` are set correctly in `claude_desktop_config.json`.

## Integrations not persisting

**Symptom**: Integration settings revert after restart.

**Solution**: Click **Apply** again after updating settings (port, API key, etc.). The integration manager rewrites the config files each time.

## macOS reports "Operation not permitted"

**Symptom**: Preflight checks fail with permission errors.

**Solution**: Grant necessary permissions in **System Settings → Privacy & Security**:
- **Files and Folders** — ensure PaglaMLX has access to your models directory.
- **Network** — allow incoming connections.

## OOM / Jetsam kills

**Symptom**: macOS terminates the model process with an out-of-memory error.

**Solutions**:
- Reduce `max_tokens` for generation.
- Load smaller quantized models (e.g., 4-bit instead of 8-bit).
- Close other memory-intensive applications.
- Monitor memory pressure in Activity Monitor.

## Gateway crashes on startup

**Symptom**: The app launches but the gateway immediately stops.

**Solutions**:
- Check that `mlx-lm`, `fastapi`, `uvicorn`, and `httpx` are installed.
- Try setting the Python path manually.
- Check Console.app for crash logs from the Python process.
- Delete `~/.paglamlx/` and restart the app.
