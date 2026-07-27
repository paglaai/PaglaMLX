import Foundation
import Observation
import Combine
import AppKit

/// Manages a FastAPI-based Python HTTP reverse proxy that routes requests
/// to the correct `mlx_lm.server` instance based on the requested model name.
@MainActor
@Observable final class RoutingGateway {
    static let shared = RoutingGateway()
    
    var isRunning = false
    var port: Int
    var recentErrors: [String] = []
    
    private var process: Process?
    private var stderrPipe: Pipe?
    
    private init() {
        self.port = SettingsManager.shared.port
    }
    
    func start() {
        let settings = SettingsManager.shared
        guard !settings.pythonPath.isEmpty else { return }
        
        // Write the python gateway script to disk
        let script = """
import os, sys, json, httpx, asyncio, re, time
from fastapi import FastAPI, Request, Response
from fastapi.responses import StreamingResponse
import uvicorn

app = FastAPI(title="PaglaMLX Routing Gateway")

API_KEY = os.environ.get("LENGTA_API_KEY", "")
OR_KEY = os.environ.get("OPENROUTER_KEY", "")
FREE_KEY = os.environ.get("FREE_ROUTER_KEY", "") or OR_KEY
ANT_KEY = os.environ.get("ANTHROPIC_KEY", "")
OAI_KEY = os.environ.get("OPENAI_KEY", "")
GEM_KEY = os.environ.get("GEMINI_KEY", "")
GROQ_KEY = os.environ.get("GROQ_KEY", "")
TOGETHER_KEY = os.environ.get("TOGETHER_KEY", "")
DEEPSEEK_KEY = os.environ.get("DEEPSEEK_KEY", "")
MISTRAL_KEY = os.environ.get("MISTRAL_KEY", "")
PERPLEXITY_KEY = os.environ.get("PERPLEXITY_KEY", "")
COHERE_KEY = os.environ.get("COHERE_KEY", "")
FIREWORKS_KEY = os.environ.get("FIREWORKS_KEY", "")
HYPERBOLIC_KEY = os.environ.get("HYPERBOLIC_KEY", "")
SAMBANOVA_KEY = os.environ.get("SAMBANOVA_KEY", "")
FREE_ROUTER = os.environ.get("FREE_ROUTER_ENABLED", "false").lower() == "true"

MTPLX_PORT = 8000
VLLM_PORT = 8001
MLX_LM_PORT = 8080

def is_external_model(model_name):
    if not model_name:
        return False
    name_lower = model_name.lower()
    if name_lower == "free":
        return True
    if name_lower.startswith("gpt-") or name_lower.startswith("o1") or name_lower.startswith("o3"):
        return True
    if name_lower.startswith("claude-"):
        return True
    if name_lower.startswith("gemini-"):
        return True
    if name_lower.startswith("openrouter/"):
        return True
    return False

def smart_route(body, headers):
    if body and has_image_content(body):
        return VLLM_PORT
    
    agent_count_hdr = headers.get("x-agent-count")
    swarm_mode_hdr = headers.get("x-swarm-mode", "").lower()
    
    is_swarm = False
    if swarm_mode_hdr == "true":
        is_swarm = True
    elif agent_count_hdr:
        try:
            if int(agent_count_hdr) > 1:
                is_swarm = True
        except ValueError:
            pass
            
    if is_swarm:
        return VLLM_PORT
        
    if body and "tools" in body and body["tools"]:
        return MTPLX_PORT
        
    return MTPLX_PORT

ROUTING_FILE = os.path.expanduser("~/.lengtamlx/routes.json")
EVENTS_FILE = os.path.expanduser("~/.lengtamlx/events.jsonl")

session_routes = {}

# ---------------------------------------------------------------------------
# Event Logging
# ---------------------------------------------------------------------------

import threading
import uuid as _uuid

def _ensure_events_dir():
    d = os.path.dirname(EVENTS_FILE)
    os.makedirs(d, exist_ok=True)

_events_lock = threading.Lock()

def record_event(event_type, model, request_id, status, duration_ms, message=None):
    def _write():
        event = {
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "event_type": event_type,
            "model": model,
            "request_id": request_id,
            "status": status,
            "duration_ms": duration_ms,
        }
        if message is not None:
            event["message"] = message
        line = json.dumps(event) + "\n"
        with _events_lock:
            try:
                _ensure_events_dir()
                with open(EVENTS_FILE, "a", encoding="utf-8") as f:
                    f.write(line)
            except Exception as exc:
                sys.stderr.write(f"[events] write failed: {exc}\n")
    t = threading.Thread(target=_write, daemon=True)
    t.start()



# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def get_local_routes():
    try:
        with open(ROUTING_FILE) as f:
            return json.load(f)
    except Exception:
        return {}

def normalize_routes(local_routes):
    \"\"\"Ensure all route entries are dicts with port/context_length/model_type.\"\"\"
    normalized = {}
    for name, val in local_routes.items():
        if isinstance(val, dict):
            normalized[name] = val
        else:
            normalized[name] = {"port": val, "context_length": 4096, "model_type": "LLM"}
    return normalized

def target_for_model(local_routes, model_name):
    if not model_name:
        return None
    for key in list(local_routes.keys()):
        if model_name == key:
            return local_routes[key].get("port") if isinstance(local_routes[key], dict) else local_routes[key]
    name_lower = model_name.lower()
    for key in local_routes:
        if key.lower() in name_lower or name_lower in key.lower():
            entry = local_routes[key]
            return entry.get("port") if isinstance(entry, dict) else entry
    return None

def first_local_port(local_routes):
    for v in local_routes.values():
        if isinstance(v, dict):
            return v.get("port")
        return v
    return None

# ---------------------------------------------------------------------------
# OpenAI-format error response
# ---------------------------------------------------------------------------

def openai_error(message, code="server_error", status=502):
    return Response(
        content=json.dumps({
            "error": {
                "message": message,
                "type": code,
                "param": None,
                "code": code
            }
        }),
        status_code=status,
        media_type="application/json"
    )

# ---------------------------------------------------------------------------
# Anthropic → OpenAI message translation
# ---------------------------------------------------------------------------

def translate_anthropic_messages(body):
    \"\"\"Convert Anthropic /v1/messages body to OpenAI /v1/chat/completions body.\"\"\"
    out_messages = []

    if "system" in body and body["system"]:
        if isinstance(body["system"], str):
            out_messages.append({"role": "system", "content": body["system"]})
        elif isinstance(body["system"], list):
            text = " ".join(b.get("text", "") for b in body["system"] if b.get("type") == "text")
            out_messages.append({"role": "system", "content": text})

    for msg in body.get("messages", []):
        role = msg.get("role", "user")
        content = msg.get("content", "")

        if role == "user":
            if isinstance(content, str):
                out_messages.append({"role": "user", "content": content})
            elif isinstance(content, list):
                text_parts = []
                for block in content:
                    if block.get("type") == "text":
                        text_parts.append(block.get("text", ""))
                    elif block.get("type") == "tool_result":
                        tool_content = block.get("content", "")
                        if isinstance(tool_content, list):
                            tool_content = " ".join(b.get("text", "") for b in tool_content if b.get("type") == "text")
                        out_messages.append({
                            "role": "tool",
                            "tool_call_id": block.get("tool_use_id", ""),
                            "content": str(tool_content) if tool_content else ""
                        })
                if text_parts:
                    out_messages.append({"role": "user", "content": "\\n".join(text_parts)})

        elif role == "assistant":
            if isinstance(content, str):
                out_messages.append({"role": "assistant", "content": content})
            elif isinstance(content, list):
                text = ""
                tool_calls = []
                for block in content:
                    bt = block.get("type", "")
                    if bt == "text":
                        text += block.get("text", "")
                    elif bt == "tool_use":
                        args = json.dumps(block.get("input", {}))
                        tool_calls.append({
                            "id": block.get("id", ""),
                            "type": "function",
                            "function": {
                                "name": block.get("name", ""),
                                "arguments": args
                            }
                        })
                if tool_calls:
                    out_messages.append({"role": "assistant", "content": text or None, "tool_calls": tool_calls})
                else:
                    out_messages.append({"role": "assistant", "content": text})

    tools = None
    if "tools" in body:
        tools = []
        for t in body["tools"]:
            tools.append({
                "type": "function",
                "function": {
                    "name": t.get("name", ""),
                    "description": t.get("description", ""),
                    "parameters": t.get("input_schema", {})
                }
            })

    oaibody = {
        "model": "default_model",
        "messages": out_messages,
        "stream": body.get("stream", False),
        "max_tokens": body.get("max_tokens", 4096),
    }
    if body.get("temperature") is not None:
        oaibody["temperature"] = body["temperature"]
    if body.get("top_p") is not None:
        oaibody["top_p"] = body["top_p"]
    if body.get("top_k") is not None:
        oaibody["top_k"] = body["top_k"]
    if body.get("stop_sequences"):
        oaibody["stop"] = body["stop_sequences"]
    if tools:
        oaibody["tools"] = tools

    return oaibody

# ---------------------------------------------------------------------------
# OpenAI → Anthropic non-streaming response translation
# ---------------------------------------------------------------------------

def translate_nonstream_response(openai_data, model_name):
    choice = openai_data.get("choices", [{}])[0]
    msg = choice.get("message", {})
    content_blocks = []
    tool_calls = msg.get("tool_calls")

    if msg.get("content"):
        content_blocks.append({"type": "text", "text": msg["content"]})

    if tool_calls:
        for tc in tool_calls:
            try:
                args = json.loads(tc["function"]["arguments"])
            except Exception:
                args = {}
            content_blocks.append({
                "type": "tool_use",
                "id": tc["id"],
                "name": tc["function"]["name"],
                "input": args
            })

    finish = choice.get("finish_reason", "stop")
    stop_reason = {"stop": "end_turn", "tool_calls": "tool_use", "length": "max_tokens"}.get(finish, finish)

    usage = openai_data.get("usage", {})
    return {
        "id": openai_data.get("id", "msg_0000000000"),
        "type": "message",
        "role": "assistant",
        "content": content_blocks,
        "model": model_name,
        "stop_reason": stop_reason,
        "stop_sequence": None,
        "usage": {
            "input_tokens": usage.get("prompt_tokens", 0),
            "output_tokens": usage.get("completion_tokens", 0)
        }
    }

# ---------------------------------------------------------------------------
# OpenAI → Anthropic streaming translation
# ---------------------------------------------------------------------------

def translate_stream_chunk(data, model_name, state):
    \"\"\"Yield zero or more SSE text fragments for a single OpenAI chunk.\"\"\"
    choices = data.get("choices", [])
    if not choices:
        return
    delta = choices[0].get("delta", {})
    finish_reason = choices[0].get("finish_reason")

    text = delta.get("content", "")
    tool_calls = delta.get("tool_calls")

    if text and not state["text_started"]:
        state["text_started"] = True
        yield 'event: content_block_start\\ndata: {}\\n\\n'.format(json.dumps({
            "type": "content_block_start",
            "index": 0,
            "content_block": {"type": "text", "text": ""}
        }))

    if text:
        yield 'event: content_block_delta\\ndata: {}\\n\\n'.format(json.dumps({
            "type": "content_block_delta",
            "index": 0,
            "delta": {"type": "text_delta", "text": text}
        }))

    if tool_calls:
        for tc in tool_calls:
            idx = tc.get("index", 0)
            func = tc.get("function", {})
            name = func.get("name", "")
            args = func.get("arguments", "")

            if name and idx not in state["tool_indices"]:
                state["tool_indices"].add(idx)
                yield 'event: content_block_start\\ndata: {}\\n\\n'.format(json.dumps({
                    "type": "content_block_start",
                    "index": len(state["tool_indices"]),
                    "content_block": {"type": "tool_use", "id": tc.get("id", ""), "name": name, "input": {}}
                }))

            if args:
                yield 'event: content_block_delta\\ndata: {}\\n\\n'.format(json.dumps({
                    "type": "content_block_delta",
                    "index": len(state["tool_indices"]),
                    "delta": {"type": "input_json_delta", "partial_json": args}
                }))

    if finish_reason:
        if state["text_started"]:
            yield 'event: content_block_stop\\ndata: {"type":"content_block_stop","index":0}\\n\\n'
        for idx in state["tool_indices"]:
            yield 'event: content_block_stop\\ndata: {}\\n\\n'.format(json.dumps({
                "type": "content_block_stop", "index": idx
            }))

        stop_map = {"stop": "end_turn", "tool_calls": "tool_use", "length": "max_tokens"}
        reason = stop_map.get(finish_reason, finish_reason)
        usage = data.get("usage", {})
        yield 'event: message_delta\\ndata: {}\\n\\n'.format(json.dumps({
            "type": "message_delta",
            "delta": {"stop_reason": reason, "stop_sequence": None},
            "usage": {"output_tokens": usage.get("completion_tokens", 0)}
        }))
        yield 'event: message_stop\\ndata: {"type":"message_stop"}\\n\\n'

# ---------------------------------------------------------------------------
# Middleware
# ---------------------------------------------------------------------------

@app.middleware("http")
async def check_auth(request: Request, call_next):
    if API_KEY and request.method != "OPTIONS":
        auth = request.headers.get("authorization", "")
        if auth != f"Bearer {API_KEY}":
            return openai_error("Unauthorized", "authentication_error", 401)
    return await call_next(request)

# ---------------------------------------------------------------------------
# Provider compliance endpoints
# ---------------------------------------------------------------------------

@app.get("/health")
async def health():
    return {"status": "ok", "version": "1.3.0"}

MODELS_DIR = os.environ.get("MODELS_DIR", "")

@app.get("/v1/models")
async def list_models():
    local_routes = get_local_routes()
    now_ts = int(time.time())
    model_set = {}

    # Running local models
    for name in local_routes:
        model_set[name] = {"id": name, "object": "model", "created": now_ts, "owned_by": "local"}

    # Available local models from disk (not yet running)
    if MODELS_DIR and os.path.isdir(MODELS_DIR):
        for entry in sorted(os.listdir(MODELS_DIR)):
            model_path = os.path.join(MODELS_DIR, entry)
            if os.path.isdir(model_path) and entry not in model_set:
                model_set[entry] = {"id": entry, "object": "model", "created": now_ts, "owned_by": "local"}

    # Configured cloud models
    if OAI_KEY:
        for mid in ("gpt-4o", "gpt-4o-mini", "gpt-4.1", "o3-mini"):
            model_set[mid] = {"id": mid, "object": "model", "created": now_ts, "owned_by": "openai"}
    if ANT_KEY:
        for mid in ("claude-sonnet-4-20250514", "claude-3-5-haiku-latest", "claude-opus-4-20250514"):
            model_set[mid] = {"id": mid, "object": "model", "created": now_ts, "owned_by": "anthropic"}
    if GEM_KEY:
        model_set["gemini-2.0-flash"] = {"id": "gemini-2.0-flash", "object": "model", "created": now_ts, "owned_by": "google"}
    if has_any_free_key():
        model_set["free"] = {"id": "free", "object": "model", "created": now_ts, "owned_by": "free_router"}
    if OR_KEY:
        model_set["openrouter/auto"] = {"id": "openrouter/auto", "object": "model", "created": now_ts, "owned_by": "openrouter"}

    return {"object": "list", "data": list(model_set.values())}

# ---------------------------------------------------------------------------
# Anthropic /v1/messages endpoint (native translation)
# ---------------------------------------------------------------------------

async def pass_through_anthropic(client, url, headers, body, model_name, req_id=None, t0=None):
    if req_id is None:
        req_id = str(_uuid.uuid4())[:8]
    if t0 is None:
        t0 = time.time()
    
    is_stream = body.get("stream", False)
    req = client.build_request("POST", url, headers=headers, json=body)
    
    if is_stream:
        response = await client.send(req, stream=True)
        if response.status_code != 200:
            _dur = int((time.time() - t0) * 1000)
            record_event("request", model_name, req_id, "failed", _dur, f"HTTP {response.status_code}")
            return anthropic_error("api_error", f"Upstream model error (HTTP {response.status_code})")
            
        async def generator():
            async for chunk in response.aiter_bytes():
                yield chunk
            _dur = int((time.time() - t0) * 1000)
            record_event("request", model_name, req_id, "success", _dur)
            
        return StreamingResponse(generator(), status_code=200, media_type="text/event-stream")
    else:
        response = await client.send(req, stream=False)
        _dur = int((time.time() - t0) * 1000)
        if response.status_code != 200:
            record_event("request", model_name, req_id, "failed", _dur, f"HTTP {response.status_code}")
            return anthropic_error("api_error", f"Upstream model error (HTTP {response.status_code})")
        record_event("request", model_name, req_id, "success", _dur)
        return Response(content=response.content, status_code=200, media_type="application/json")

@app.post("/v1/messages")
async def anthropic_messages(request: Request):
    try:
        body = await request.json()
    except Exception:
        return anthropic_error("invalid_request_error", "Invalid JSON body")

    local_routes = normalize_routes(get_local_routes())
    model_name = body.get("model", "default")

    port = target_for_model(local_routes, model_name)
    if port is None:
        port = smart_route(body, request.headers)

    if port == MTPLX_PORT:
        target_url = f"http://127.0.0.1:{MTPLX_PORT}/v1/messages"
        fwd_headers = {"Content-Type": "application/json"}
        if API_KEY:
            fwd_headers["Authorization"] = f"Bearer {API_KEY}"
        
        client = httpx.AsyncClient(timeout=None)
        _req_id = str(_uuid.uuid4())[:8]
        _t0 = time.time()
        try:
            return await pass_through_anthropic(client, target_url, fwd_headers, body, model_name, _req_id, _t0)
        except Exception as e:
            _dur = int((time.time() - _t0) * 1000)
            record_event("request", model_name, _req_id, "failed", _dur, str(e)[:120])
            return anthropic_error("api_error", f"MTPLX connection error: {str(e)}")

    target_url = f"http://127.0.0.1:{port}/v1/chat/completions"
    oaibody = translate_anthropic_messages(body)
    is_stream = body.get("stream", False)

    oai_headers = {"Content-Type": "application/json"}
    if API_KEY:
        oai_headers["Authorization"] = f"Bearer {API_KEY}"

    client = httpx.AsyncClient(timeout=None)
    _req_id = str(_uuid.uuid4())[:8]
    _t0 = time.time()

    try:
        if is_stream:
            return await stream_anthropic(client, target_url, oai_headers, oaibody, model_name, _req_id, _t0)
        else:
            return await nonstream_anthropic(client, target_url, oai_headers, oaibody, model_name, _req_id, _t0)
    except httpx.HTTPStatusError as e:
        _dur = int((time.time() - _t0) * 1000)
        record_event("request", model_name, _req_id, "failed", _dur, f"HTTP {e.response.status_code}")
        sys.stderr.write(f"MLX server HTTP error: {e.response.status_code}\n")
        return anthropic_error("api_error", f"Upstream model error (HTTP {e.response.status_code})")
    except httpx.ConnectError:
        _dur = int((time.time() - _t0) * 1000)
        record_event("request", model_name, _req_id, "failed", _dur, "connect_error")
        return anthropic_error("api_error", f"Cannot connect to local backend server at port {port}.")
    except Exception as e:
        _dur = int((time.time() - _t0) * 1000)
        record_event("request", model_name, _req_id, "failed", _dur, str(e)[:120])
        sys.stderr.write(f"Anthropic proxy error: {e}\n")
        return anthropic_error("api_error", f"Internal proxy error: {str(e)}")


async def stream_anthropic(client, url, headers, oaibody, model_name, req_id=None, t0=None):
    if req_id is None:
        req_id = str(_uuid.uuid4())[:8]
    if t0 is None:
        t0 = time.time()
    req = client.build_request("POST", url, headers=headers, json=oaibody)
    response = await client.send(req, stream=True)

    state = {"text_started": False, "tool_indices": set()}

    async def generator():
        yield 'event: message_start\ndata: {}\n\n'.format(json.dumps({
            "type": "message_start",
            "message": {
                "id": "msg_0000000000",
                "type": "message",
                "role": "assistant",
                "content": [],
                "model": model_name,
                "stop_reason": None,
                "stop_sequence": None,
                "usage": {"input_tokens": 0, "output_tokens": 0}
            }
        }))

        async for line in response.aiter_lines():
            if not line.startswith("data: "):
                continue
            payload = line[6:]
            if payload.strip() == "[DONE]":
                break
            try:
                data = json.loads(payload)
            except json.JSONDecodeError:
                continue
            for event in translate_stream_chunk(data, model_name, state):
                yield event + "\n"
        _dur = int((time.time() - t0) * 1000)
        record_event("request", model_name, req_id, "success", _dur)

    return StreamingResponse(generator(), media_type="text/event-stream")


async def nonstream_anthropic(client, url, headers, oaibody, model_name, req_id=None, t0=None):
    if req_id is None:
        req_id = str(_uuid.uuid4())[:8]
    if t0 is None:
        t0 = time.time()
    response = await client.post(url, headers=headers, json=oaibody)
    _dur = int((time.time() - t0) * 1000)
    if response.status_code != 200:
        record_event("request", model_name, req_id, "failed", _dur, f"HTTP {response.status_code}")
        return anthropic_error("api_error", f"Model returned HTTP {response.status_code}")
    data = response.json()
    anthropic_data = translate_nonstream_response(data, model_name)
    record_event("request", model_name, req_id, "success", _dur)
    return Response(content=json.dumps(anthropic_data), media_type="application/json")


def anthropic_error(type_, message):
    return Response(
        content=json.dumps({"type": "error", "error": {"type": type_, "message": message}}),
        status_code=400,
        media_type="application/json"
    )

# ---------------------------------------------------------------------------
# OpenAI /v1/chat/completions catch-all proxy (existing)
# ---------------------------------------------------------------------------

def get_session_id(request: Request):
    return request.headers.get("x-session-id") or request.headers.get("authorization", "default")

def has_image_content(body):
    \"\"\"Check if the request body contains image_url or image data content.\"\"\"
    if not body or "messages" not in body:
        return False
    for msg in body.get("messages", []):
        content = msg.get("content", "")
        if isinstance(content, list):
            for block in content:
                if isinstance(block, dict) and block.get("type") in ("image_url", "image"):
                    return True
    return False

def suggests_vlm(model_name):
    \"\"\"Heuristic: does the model name suggest vision/language support?\"\"\"
    if not model_name:
        return False
    name = model_name.lower()
    return any(kw in name for kw in ("vl", "vision", " multimodal", "vlm", "4v", "phi-3-v", "llava", "cogview", "idefics", "fuyu", "paligemma", "qwen2-vl", "internvl", "minicpm-v"))

# ---------------------------------------------------------------------------
# Auto-Router Heuristic Engine
# ---------------------------------------------------------------------------

def estimate_token_count(body):
    \"\"\"Rough token count estimation from messages (~4 chars/token).\"\"\"
    if not body or "messages" not in body:
        return 0
    total_chars = 0
    for msg in body.get("messages", []):
        content = msg.get("content", "")
        if isinstance(content, str):
            total_chars += len(content)
        elif isinstance(content, list):
            for block in content:
                if isinstance(block, dict):
                    if block.get("type") == "text":
                        total_chars += len(block.get("text", ""))
                    if block.get("type") == "image_url":
                        total_chars += 4000
    return total_chars // 4

def detect_intent(body):
    \"\"\"Detect user intent from message content.\"\"\"
    if not body or "messages" not in body:
        return "general"
    text = ""
    for msg in body.get("messages", []):
        content = msg.get("content", "")
        if isinstance(content, str):
            text += " " + content
        elif isinstance(content, list):
            for block in content:
                if isinstance(block, dict) and block.get("type") == "text":
                    text += " " + block.get("text", "")
    text_lower = text.lower()
    code_kws = ["code", "function", "implement", "debug", "bug", "fix", "refactor",
                "algorithm", "syntax", "compile", "```", "def ", "class ", "import ",
                "const ", "var ", "program"]
    math_kws = ["solve", "equation", "calculate", "derivative", "integral",
                "theorem", "proof", "algebra", "calculus"]
    reasoning_kws = ["explain", "reason", "analyze", "compare", "contrast",
                     "why", "how does", "what if", "think step by step"]
    code_score = sum(1 for kw in code_kws if kw in text_lower)
    math_score = sum(1 for kw in math_kws if kw in text_lower)
    reasoning_score = sum(1 for kw in reasoning_kws if kw in text_lower)
    if code_score >= 2 or math_score >= 2:
        return "technical"
    if reasoning_score >= 2:
        return "reasoning"
    return "general"

def get_vlm_on_disk():
    \"\"\"Return list of VLM model names available on disk but not running.\"\"\"
    if not MODELS_DIR or not os.path.isdir(MODELS_DIR):
        return []
    results = []
    for entry in sorted(os.listdir(MODELS_DIR)):
        model_path = os.path.join(MODELS_DIR, entry)
        if os.path.isdir(model_path):
            config_path = os.path.join(model_path, "config.json")
            if os.path.isfile(config_path):
                try:
                    with open(config_path) as f:
                        config = json.load(f)
                    archs = config.get("architectures", [])
                    if any("vl" in a.lower() or "vision" in a.lower() for a in archs):
                        results.append(entry)
                except Exception:
                    pass
    return results

def auto_route(body, local_routes):
    \"\"\"Auto-Router heuristic: pick the best running local model for this request.\"\"\"
    if not local_routes:
        return None
    has_images = has_image_content(body)
    estimated_tokens = estimate_token_count(body) if body else 0
    intent = detect_intent(body) if body else "general"
    best_port = None
    best_score = -999
    for name, info in local_routes.items():
        port = info.get("port")
        ct_length = info.get("context_length", 4096)
        mtype = info.get("model_type", "LLM")
        score = 0
        if has_images:
            if mtype == "VLM":
                score += 1000
            else:
                continue
        if estimated_tokens > 0:
            if estimated_tokens > ct_length:
                continue
            ratio = estimated_tokens / ct_length
            if ratio > 0.5:
                score += 50
            elif ratio > 0.2:
                score += 30
            else:
                score += 10
        if intent == "technical":
            score += 20
        elif intent == "reasoning":
            score += 15
        if best_port is None or score > best_score:
            best_port = port
            best_score = score
    if best_port:
        return best_port
    if has_images:
        vlm_list = get_vlm_on_disk()
        if vlm_list:
            sys.stderr.write(f"[auto-router] Image request but no VLM running. Available on disk: {', '.join(vlm_list)}\\n")
    return None

# ---------------------------------------------------------------------------
# Multi-Provider Free Router
# ---------------------------------------------------------------------------

FREE_PROVIDERS = [
    ("openrouter", "https://openrouter.ai/api", "FREE_ROUTER_KEY", "openrouter/auto"),
    ("groq", "https://api.groq.com/openai", "GROQ_KEY", "llama-3.3-70b-versatile"),
    ("together", "https://api.together.xyz", "TOGETHER_KEY", "mistralai/Mixtral-8x22B-Instruct-v0.1"),
    ("deepseek", "https://api.deepseek.com", "DEEPSEEK_KEY", "deepseek-chat"),
    ("mistral", "https://api.mistral.ai", "MISTRAL_KEY", "mistral-small-latest"),
    ("perplexity", "https://api.perplexity.ai", "PERPLEXITY_KEY", "sonar"),
    ("cohere", "https://api.cohere.com", "COHERE_KEY", "command-r"),
    ("fireworks", "https://api.fireworks.ai", "FIREWORKS_KEY", "accounts/fireworks/models/llama-v3p1-8b-instruct"),
    ("hyperbolic", "https://api.hyperbolic.xyz", "HYPERBOLIC_KEY", "meta-llama/Llama-3.3-70B-Instruct"),
    ("sambanova", "https://api.sambanova.ai", "SAMBANOVA_KEY", "Meta-Llama-3.3-70B-Instruct"),
]

free_provider_health = {}

def init_free_provider_health():
    for name, _, env_key, _ in FREE_PROVIDERS:
        key = os.environ.get(env_key, "")
        free_provider_health[name] = {
            "successes": 0, "failures": 0, "cooldown_until": 0,
            "configured": bool(key), "last_error": ""
        }

init_free_provider_health()

def has_any_free_key():
    return any(h["configured"] for h in free_provider_health.values())

async def try_free_providers(path, body, fwd_headers):
    \"\"\"Try each configured free provider in weighted-random order until one succeeds.\"\"\"
    now = time.time()
    eligible = []
    for name, base_url, env_key, model in FREE_PROVIDERS:
        key = os.environ.get(env_key, "")
        if not key:
            continue
        health = free_provider_health[name]
        if now < health["cooldown_until"]:
            continue
        eligible.append((name, base_url, env_key, model, health))
    if not eligible:
        return None, "No free providers are configured or available. Add API keys in Settings → Cloud."
    random.shuffle(eligible)
    eligible.sort(key=lambda x: x[4]["successes"] - x[4]["failures"] * 3, reverse=True)
    last_error = ""
    for name, base_url, env_key, model, health in eligible:
        key = os.environ.get(env_key, "")
        url = f"{base_url}/{path}"
        headers = dict(fwd_headers)
        headers["authorization"] = f"Bearer {key}"
        headers.pop("x-api-key", None)
        headers.pop("anthropic-version", None)
        req_body = dict(body) if body else {}
        req_body["model"] = model
        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                resp = await client.post(url, headers=headers, json=req_body, timeout=60.0)
                if resp.status_code == 200:
                    health["successes"] += 1
                    health["failures"] = max(0, health["failures"] - 1)
                    health["cooldown_until"] = 0
                    return resp, None
                elif resp.status_code == 429:
                    retry_after = int(resp.headers.get("retry-after", "30"))
                    health["failures"] += 1
                    cool = min(retry_after * health["failures"], 300)
                    health["cooldown_until"] = now + cool
                    health["last_error"] = "rate_limited"
                    last_error = f"{name}: rate limited (retry-after={retry_after}s)"
                else:
                    health["failures"] += 1
                    if health["failures"] >= 3:
                        health["cooldown_until"] = now + 60
                    health["last_error"] = f"HTTP_{resp.status_code}"
                    last_error = f"{name}: HTTP {resp.status_code}"
        except Exception as e:
            health["failures"] += 1
            if health["failures"] >= 3:
                health["cooldown_until"] = now + 60
            health["last_error"] = str(e)[:80]
            last_error = f"{name}: {str(e)[:80]}"
    return None, f"All free providers failed. Last error: {last_error}"

@app.api_route("/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "OPTIONS", "HEAD", "PATCH"])
async def proxy(request: Request, path: str):
    if path.startswith("v1/messages"):
        return await anthropic_messages(request)

    local_routes = normalize_routes(get_local_routes())
    
    model_name = None
    body = None
    if request.method == "POST":
        try:
            body = await request.json()
            model_name = body.get("model")
        except:
            pass
            
    # Reject image content for non-VLM local models before routing
    if body and has_image_content(body) and model_name and model_name in local_routes:
        if not suggests_vlm(model_name):
            return openai_error(
                f"The model '{model_name}' does not support image input. "
                f"Use a VLM model (e.g., one with 'vl' or 'vision' in the name) for image understanding.",
                "invalid_request_error", 400
            )

    session_id = get_session_id(request)
    target_url = None
    fwd_headers = dict(request.headers)
    fwd_headers.pop("host", None)
    fwd_headers.pop("content-length", None)
    
    # 1. Check local models
    if model_name and model_name in local_routes:
        target_url = f"http://127.0.0.1:{local_routes[model_name]['port']}/{path}"
        if body is not None:
            body["model"] = "default_model"
    
    # 1b. Auto-Router: heuristic for model=auto or unknown local model
    elif model_name and (model_name.lower() == "auto" or (model_name not in local_routes and not is_external_model(model_name))):
        target_port = smart_route(body, request.headers)
        target_url = f"http://127.0.0.1:{target_port}/{path}"
        if body is not None:
            body["model"] = "default_model"
    
    # 2. Heuristics for external APIs
    elif model_name:
        name_lower = model_name.lower()
        
        # model=free → Multi-Provider Free Router failover chain
        if name_lower == "free":
            if not has_any_free_key():
                return openai_error(
                    "No free provider keys configured. Add at least one key in Settings → Cloud.",
                    "free_router_unconfigured", 503
                )
            resp, err = await try_free_providers(path, body, fwd_headers)
            if resp is None:
                return openai_error(err, "free_router_error", 503)
            async def free_stream():
                async for chunk in resp.aiter_bytes():
                    yield chunk
            return StreamingResponse(
                free_stream(),
                status_code=resp.status_code,
                headers=dict(resp.headers)
            )
            
        elif name_lower.startswith("gpt-") or name_lower.startswith("o1") or name_lower.startswith("o3"):
            if OAI_KEY:
                target_url = f"https://api.openai.com/{path}"
                fwd_headers["authorization"] = f"Bearer {OAI_KEY}"
                
        elif name_lower.startswith("claude-"):
            if ANT_KEY:
                target_url = f"https://api.anthropic.com/{path}"
                fwd_headers["x-api-key"] = ANT_KEY
                fwd_headers.pop("authorization", None)
                
        elif name_lower.startswith("gemini-"):
            if GEM_KEY:
                target_url = f"https://generativelanguage.googleapis.com/{path}"
                fwd_headers["authorization"] = f"Bearer {GEM_KEY}"
                
        elif name_lower.startswith("openrouter/") or FREE_ROUTER:
            target_url = f"https://openrouter.ai/api/{path}"
            if OR_KEY:
                fwd_headers["authorization"] = f"Bearer {OR_KEY}"
    
    # 3. Stickiness fallback
    if not target_url and session_id in session_routes:
        base = session_routes[session_id].get("base")
        if not base:
            return openai_error("Corrupted session route.", "session_error", 500)
        auth_header = session_routes[session_id].get("auth")
        if auth_header:
            fwd_headers["authorization"] = auth_header
        xak = session_routes[session_id].get("x-api-key")
        if xak:
            fwd_headers["x-api-key"] = xak
            fwd_headers.pop("authorization", None)
            
        target_url = f"{base}/{path}"
        # Override model name for local mlx_lm.server destinations
        if body is not None and base.startswith("http://127.0.0.1"):
            body["model"] = "default_model"
        
    # 4. Local Default Fallback
    if not target_url:
        if local_routes:
            port = list(local_routes.values())[0]["port"]
            target_url = f"http://127.0.0.1:{port}/{path}"
        else:
            target_url = f"http://127.0.0.1:{MTPLX_PORT}/{path}"
        if body is not None:
            body["model"] = "default_model"

    # 5. Post-routing VLM guard
    if target_url and body and has_image_content(body) and target_url.startswith("http://127.0.0.1"):
        try:
            target_port = int(target_url.split(":")[2].split("/")[0])
        except (ValueError, IndexError):
            target_port = None
        if target_port is not None:
            is_vlm = target_port == VLLM_PORT or any(
                isinstance(info, dict) and info.get("port") == target_port and info.get("model_type") == "VLM"
                for info in local_routes.values()
            )
            if not is_vlm:
                return openai_error(
                    "The current model does not support image input. "
                    "Switch to a VLM model (e.g., one with 'vl' or 'vision' in the name) for image understanding.",
                    "invalid_request_error", 400
                )

    if not target_url:
        return openai_error("No route available — no model is running and no cloud provider is configured.", "no_route", 503)
        
    # Save stickiness (only store truthy headers, never None)
    base_url = target_url[:target_url.rfind(f"/{path}")]
    session_routes[session_id] = {"base": base_url}
    auth_val = fwd_headers.get("authorization")
    xak_val = fwd_headers.get("x-api-key")
    if auth_val:
        session_routes[session_id]["auth"] = auth_val
    if xak_val:
        session_routes[session_id]["x-api-key"] = xak_val
    
    client = httpx.AsyncClient(timeout=None)
    _req_id = str(_uuid.uuid4())[:8]
    _t0 = time.time()
    _model_name = model_name or "local"
    
    try:
        if body is not None:
            req = client.build_request(request.method, target_url, headers=fwd_headers, json=body)
        else:
            req = client.build_request(request.method, target_url, headers=fwd_headers, content=request.stream())
            
        response = await client.send(req, stream=True)
        _status_code = response.status_code
        
        async def stream_generator():
            async for chunk in response.aiter_bytes():
                yield chunk
            _dur = int((time.time() - _t0) * 1000)
            _ev_status = "success" if _status_code < 400 else "failed"
            record_event("request", _model_name, _req_id, _ev_status, _dur)
                
        return StreamingResponse(
            stream_generator(),
            status_code=response.status_code,
            headers=dict(response.headers)
        )
    except httpx.HTTPStatusError as e:
        _dur = int((time.time() - _t0) * 1000)
        record_event("request", _model_name, _req_id, "failed", _dur, f"HTTP {e.response.status_code}")
        sys.stderr.write(f"HTTP error from {target_url}: {e.response.status_code}\\n")
        return openai_error(f"Upstream provider returned HTTP {e.response.status_code}", "upstream_error", 502)
    except Exception as e:
        _dur = int((time.time() - _t0) * 1000)
        record_event("request", _model_name, _req_id, "failed", _dur, str(e)[:120])
        sys.stderr.write(f"Proxy error connecting to {target_url}: {str(e)}\\n")
        return openai_error(f"Proxy error: {str(e)}", "proxy_error", 502)


if __name__ == "__main__":
    port = int(sys.argv[1])
    host = sys.argv[2]
    uvicorn.run(app, host=host, port=port, log_level="warning")
"""
        let fm = FileManager.default
        let lengtaDir = fm.homeDirectoryForCurrentUser.appendingPathComponent(".lengtamlx")
        try? fm.createDirectory(at: lengtaDir, withIntermediateDirectories: true)
        
        let scriptPath = lengtaDir.appendingPathComponent("gateway.py").path
        try? script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
        
        let p = Process()
        p.executableURL = URL(fileURLWithPath: settings.pythonPath)
        p.arguments = [scriptPath, "\(settings.port)", settings.host]
        
        // Add dependency paths & environment variables
        var env = ProcessInfo.processInfo.environment
        let extraPaths = "/Library/Frameworks/Python.framework/Versions/3.14/bin"
                       + ":/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        env["PATH"] = extraPaths + ":" + (env["PATH"] ?? "")
        
        // Inject BYOK keys
        env["LENGTA_API_KEY"] = settings.apiKey
        env["OPENROUTER_KEY"] = settings.openrouterKey
        env["ANTHROPIC_KEY"] = settings.anthropicKey
        env["OPENAI_KEY"] = settings.openaiKey
        env["GEMINI_KEY"] = settings.geminiKey
        env["GROQ_KEY"] = settings.groqKey
        env["TOGETHER_KEY"] = settings.togetherKey
        env["FREE_ROUTER_KEY"] = settings.freeRouterKey
        env["FREE_ROUTER_ENABLED"] = settings.freeRouterEnabled ? "true" : "false"
        env["DEEPSEEK_KEY"] = settings.deepseekKey
        env["MISTRAL_KEY"] = settings.mistralKey
        env["PERPLEXITY_KEY"] = settings.perplexityKey
        env["COHERE_KEY"] = settings.cohereKey
        env["FIREWORKS_KEY"] = settings.fireworksKey
        env["HYPERBOLIC_KEY"] = settings.hyperbolicKey
        env["SAMBANOVA_KEY"] = settings.sambanovaKey
        env["MODELS_DIR"] = settings.modelsDirectory
        
        p.environment = env
        
        p.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isRunning = false
            }
        }
        
        let stderr = Pipe()
        p.standardError = stderr
        
        stderr.fileHandleForReading.readabilityHandler = { [weak self] h in
            let data = h.availableData
            guard !data.isEmpty, let s = String(data: data, encoding: .utf8) else { return }
            let lines = s.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            Task { @MainActor [weak self] in
                for line in lines where !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    self?.recentErrors.insert(line, at: 0)
                    if self?.recentErrors.count ?? 0 > 50 {
                        self?.recentErrors.removeLast()
                    }
                }
            }
        }
        
        do {
            try p.run()
            self.process = p
            self.stderrPipe = stderr
            self.isRunning = true
            self.port = settings.port
            self.recentErrors.removeAll()
        } catch {
            print("Failed to start gateway: \(error)")
            self.recentErrors.append("Failed to start: \(error.localizedDescription)")
        }
    }
    
    func stop() {
        process?.terminate()
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        process = nil
        stderrPipe = nil
        isRunning = false
    }
    
    /// Called by ModelOrchestrator whenever a model starts or stops
    func updateRoutingTable(_ routes: [String: [String: Any]]) {
        let fm = FileManager.default
        let lengtaDir = fm.homeDirectoryForCurrentUser.appendingPathComponent(".lengtamlx")
        try? fm.createDirectory(at: lengtaDir, withIntermediateDirectories: true)
        
        let routesFile = lengtaDir.appendingPathComponent("routes.json")
        if let data = try? JSONSerialization.data(withJSONObject: routes) {
            try? data.write(to: routesFile)
        }
    }
}
