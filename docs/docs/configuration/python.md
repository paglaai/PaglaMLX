# Python Configuration

The Python tab in Settings manages the Python environment used to run `mlx_lm.server`.

## Auto-detection

When you open the Python tab, PaglaMLX automatically searches for Python in these locations:

- Custom path (if previously set)
- `/Library/Frameworks/Python.framework/Versions/3.14/bin/python3`
- `/Library/Frameworks/Python.framework/Versions/3.13/bin/python3`
- `/opt/homebrew/bin/python3`
- `/usr/local/bin/python3`
- `/usr/bin/python3`

If found, the version is displayed and the path is saved.

## Manual configuration

If auto-detection doesn't find your Python:

1. Click **Detect** to retry.
2. Or paste the full path to your Python binary in the text field.

## Virtual environment

The app checks if your Python is inside a virtual environment (`.venv/`, `venv/`, or `.virtualenvs/`). Using a venv is recommended to keep dependencies isolated:

```bash
python3 -m venv ~/.venv/paglamlx
source ~/.venv/paglamlx/bin/activate
pip3 install mlx-lm fastapi uvicorn httpx
```

## Required packages

| Package   | Purpose                        |
|-----------|--------------------------------|
| `mlx-lm`  | Local model serving on Apple Silicon |
| `fastapi` | HTTP server for the model API  |
| `uvicorn` | ASGI server runner             |
| `httpx`   | Async HTTP client (gateway)    |

## Status indicators

| Status         | Meaning                          |
|----------------|----------------------------------|
| ✅ Valid      | Python found and working         |
| ⚠️ Invalid    | No working Python found          |
| 🔄 Checking   | Detection in progress            |
| ○ Unchecked   | Not yet verified                 |
