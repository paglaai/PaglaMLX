# Messages API (Anthropic)

`POST /v1/messages`

PaglaMLX translates Anthropic-format requests to OpenAI format and back. This enables Claude Desktop and other Anthropic-native clients to talk to local models.

## Request

```json
{
  "model": "auto",
  "messages": [
    {"role": "user", "content": "Hello!"}
  ],
  "max_tokens": 1024,
  "stream": false
}
```

### Supported parameters

| Parameter    | Type    | Description                              |
|--------------|---------|------------------------------------------|
| `model`      | string  | Model name, `auto`, or routing prefix    |
| `messages`   | array   | Array of Anthropic-format messages       |
| `system`     | string  | System prompt (top-level field)          |
| `max_tokens` | integer | Maximum tokens (required by Anthropic)   |
| `stream`     | boolean | Enable SSE streaming                     |
| `temperature`| number  | Sampling temperature                     |
| `top_p`      | number  | Nucleus sampling                         |
| `top_k`      | integer | Top-K sampling                           |

### Message content blocks

Anthropic supports structured content blocks:

```json
[
  {"role": "user", "content": [
    {"type": "text", "text": "Describe this image:"},
    {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": "..."}}
  ]}
]
```

## Response

```json
{
  "id": "msg_xxx",
  "type": "message",
  "role": "assistant",
  "content": [
    {"type": "text", "text": "Hello! How can I help you?"}
  ],
  "model": "auto",
  "stop_reason": "end_turn",
  "stop_sequence": null,
  "usage": {
    "input_tokens": 12,
    "output_tokens": 8
  }
}
```

### Streaming

When `stream: true`, the server sends SSE events in Anthropic format:

```
data: {"type": "content_block_start", "index": 0, "content_block": {"type": "text", "text": ""}}

data: {"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": "Hello"}}

data: {"type": "content_block_stop", "index": 0}

data: {"type": "message_stop"}
```

## Tool use

Anthropic tool calls are translated bidirectionally:

**Anthropic → OpenAI**: `tool_use` content blocks become `tool_calls` in the OpenAI assistant message.
**OpenAI → Anthropic**: `tool_calls` become `tool_use` content blocks, `tool` role messages become `tool_result` content blocks.
