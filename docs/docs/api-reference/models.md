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

The model IDs correspond to the names shown in the PaglaMLX model picker. Only models currently loaded by the native Swift engine through the MLX C++ bridge appear in this list.

## Health check

`GET /v1`

Returns `{ "status": "ok" }` when the native Swift-NIO gateway is running.

Local model requests stay inside the PaglaMLX process; v1.6.0 does not launch a separate Python model server.
