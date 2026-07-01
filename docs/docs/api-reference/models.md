# Models API

`GET /v1/models`

Lists all models currently loaded and available.

## Response

```json
{
  "object": "list",
  "data": [
    {
      "id": "Llama-3.2-3B-Instruct-4bit",
      "object": "model",
      "created": 1718312345
    },
    {
      "id": "Mistral-7B-Instruct-4bit",
      "object": "model",
      "created": 1718312345
    }
  ]
}
```

The model IDs correspond to the directory names in your models directory. Only models that are currently loaded (running as `mlx_lm.server` processes) appear in this list.

## Health check

`GET /v1`

Returns `{ "status": "ok" }` when the gateway is running.
