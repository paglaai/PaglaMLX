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

The model IDs correspond to the names shown in the PaglaMLX model picker. Only models currently loaded by Swift-managed `mlx_lm.server` processes appear in this list.

## Health check

`GET /v1`

Returns `{ "status": "ok" }` when the Swift-managed gateway is running.

Local model requests are dispatched from the gateway to the selected Python model server process.
