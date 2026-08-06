# Chat Completions API

`POST /v1/chat/completions`

Standard OpenAI-compatible endpoint. Accepts all common parameters.

## Request

```json
{
  "model": "auto",
  "messages": [
    {"role": "system", "content": "You are a helpful assistant."},
    {"role": "user", "content": "Hello!"}
  ],
  "temperature": 0.7,
  "max_tokens": 1024,
  "stream": false
}
```

### Parameters

| Parameter     | Type    | Default | Description                              |
|---------------|---------|---------|------------------------------------------|
| `model`       | string  | required | Model name, `auto`, or routing prefix  |
| `messages`    | array   | required | Array of message objects                 |
| `temperature` | number  | 0.0     | Sampling temperature                     |
| `top_p`       | number  | 1.0     | Nucleus sampling                         |
| `top_k`       | integer | 0       | Top-K sampling (0 = disabled)            |
| `min_p`       | number  | 0.0     | Minimum probability                      |
| `max_tokens`  | integer | 512     | Maximum tokens to generate               |
| `stream`      | boolean | false   | Enable SSE streaming                     |

### Message roles

| Role     | Description              |
|----------|--------------------------|
| `system` | System prompt            |
| `user`   | User message             |
| `assistant` | Assistant response    |
| `tool`   | Tool result              |

## Response (non-streaming)

```json
{
  "id": "chatcmpl-xxx",
  "object": "chat.completion",
  "created": 1718312345,
  "model": "auto",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "Hello! How can I help you today?"
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 12,
    "completion_tokens": 8,
    "total_tokens": 20
  }
}
```

## Response (streaming)

When `stream: true`, the server sends SSE events:

```
data: {"id":"chatcmpl-xxx","object":"chat.completion.chunk","choices":[{"index":0,"delta":{"role":"assistant"},"finish_reason":null}]}

data: {"id":"chatcmpl-xxx","object":"chat.completion.chunk","choices":[{"index":0,"delta":{"content":"Hello"},"finish_reason":null}]}

data: {"id":"chatcmpl-xxx","object":"chat.completion.chunk","choices":[{"index":0,"delta":{"content":"!"},"finish_reason":null}]}

data: [DONE]
```

## Example

```bash
curl http://127.0.0.1:2525/v1/chat/completions \
  -H "Authorization: Bearer $(defaults read com.paglaai.app apiKey)" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "auto",
    "messages": [{"role": "user", "content": "What is MLX?"}],
    "stream": true
  }'
```
