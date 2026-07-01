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
FREE_ROUTER = os.environ.get("FREE_ROUTER_ENABLED", "false").lower() == "true"

ROUTING_FILE = os.path.expanduser("~/.lengtamlx/routes.json")

session_routes = {}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def get_local_routes():
    try:
        with open(ROUTING_FILE) as f:
            return json.load(f)
    except Exception:
        return {}

def target_for_model(local_routes, model_name):
    if not model_name:
        return None
    if model_name in local_routes:
        return local_routes[model_name]
    name_lower = model_name.lower()
    for key in local_routes:
        if key.lower() in name_lower or name_lower in key.lower():
            return local_routes[key]
    return None

def first_local_port(local_routes):
    for v in local_routes.values():
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
        "model": body.get("model", "default"),
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
    return {"status": "ok", "version": "1.2.0"}

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
    if FREE_KEY:
        model_set["free"] = {"id": "free", "object": "model", "created": now_ts, "owned_by": "openrouter"}
    if OR_KEY:
        model_set["openrouter/auto"] = {"id": "openrouter/auto", "object": "model", "created": now_ts, "owned_by": "openrouter"}

    return {"object": "list", "data": list(model_set.values())}

# ---------------------------------------------------------------------------
# Anthropic /v1/messages endpoint (native translation)
# ---------------------------------------------------------------------------

@app.post("/v1/messages")
async def anthropic_messages(request: Request):
    try:
        body = await request.json()
    except Exception:
        return anthropic_error("invalid_request_error", "Invalid JSON body")

    local_routes = get_local_routes()
    model_name = body.get("model", "default")

    port = target_for_model(local_routes, model_name)
    if port is None:
        port = first_local_port(local_routes)
    if port is None:
        return anthropic_error("api_error", "No local model is running. Start a model first.")

    target_url = f"http://127.0.0.1:{port}/v1/chat/completions"
    oaibody = translate_anthropic_messages(body)
    is_stream = body.get("stream", False)

    oai_headers = {"Content-Type": "application/json"}
    if API_KEY:
        oai_headers["Authorization"] = f"Bearer {API_KEY}"

    client = httpx.AsyncClient(timeout=None)

    try:
        if is_stream:
            return await stream_anthropic(client, target_url, oai_headers, oaibody, model_name)
        else:
            return await nonstream_anthropic(client, target_url, oai_headers, oaibody, model_name)
    except httpx.HTTPStatusError as e:
        sys.stderr.write(f"MLX server HTTP error: {e.response.status_code}\\n")
        return anthropic_error("api_error", f"Upstream model error (HTTP {e.response.status_code})")
    except httpx.ConnectError:
        return anthropic_error("api_error", "Cannot connect to local MLX server. It may have crashed.")
    except Exception as e:
        sys.stderr.write(f"Anthropic proxy error: {e}\\n")
        return anthropic_error("api_error", f"Internal proxy error: {str(e)}")


async def stream_anthropic(client, url, headers, oaibody, model_name):
    req = client.build_request("POST", url, headers=headers, json=oaibody)
    response = await client.send(req, stream=True)

    state = {"text_started": False, "tool_indices": set()}

    async def generator():
        yield 'event: message_start\\ndata: {}\\n\\n'.format(json.dumps({
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
                yield event + "\\n"

    return StreamingResponse(generator(), media_type="text/event-stream")


async def nonstream_anthropic(client, url, headers, oaibody, model_name):
    response = await client.post(url, headers=headers, json=oaibody)
    if response.status_code != 200:
        return anthropic_error("api_error", f"Model returned HTTP {response.status_code}")
    data = response.json()
    anthropic_data = translate_nonstream_response(data, model_name)
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

@app.api_route("/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "OPTIONS", "HEAD", "PATCH"])
async def proxy(request: Request, path: str):
    if path.startswith("v1/messages"):
        return await anthropic_messages(request)

    local_routes = get_local_routes()
    
    model_name = None
    body = None
    if request.method == "POST":
        try:
            body = await request.json()
            model_name = body.get("model")
        except:
            pass
            
    session_id = get_session_id(request)
    target_url = None
    fwd_headers = dict(request.headers)
    fwd_headers.pop("host", None)
    fwd_headers.pop("content-length", None)
    
    # 1. Check local models
    if model_name and model_name in local_routes:
        target_url = f"http://127.0.0.1:{local_routes[model_name]}/{path}"
    
    # 2. Heuristics / Auto-Router for external APIs
    elif model_name:
        name_lower = model_name.lower()
        
        # model=free → Free Router via OpenRouter auto
        if name_lower == "free" and FREE_KEY:
            target_url = f"https://openrouter.ai/api/{path}"
            fwd_headers["authorization"] = f"Bearer {FREE_KEY}"
            if body and "model" in body:
                body["model"] = "openrouter/auto"
            fwd_headers["x-free-router"] = "openrouter"
            
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
        base = session_routes[session_id]["base"]
        auth_header = session_routes[session_id]["auth"]
        if auth_header:
            fwd_headers["authorization"] = auth_header
        elif "x-api-key" in session_routes[session_id]:
            fwd_headers["x-api-key"] = session_routes[session_id]["x-api-key"]
            fwd_headers.pop("authorization", None)
            
        target_url = f"{base}/{path}"
        
    # 4. Local Default Fallback
    if not target_url and local_routes:
        port = list(local_routes.values())[0]
        target_url = f"http://127.0.0.1:{port}/{path}"
        
    if not target_url:
        return openai_error("No route available — no model is running and no cloud provider is configured.", "no_route", 503)
        
    # Save stickiness
    base_url = target_url[:target_url.rfind(f"/{path}")]
    session_routes[session_id] = {
        "base": base_url, 
        "auth": fwd_headers.get("authorization"),
        "x-api-key": fwd_headers.get("x-api-key")
    }
    
    client = httpx.AsyncClient(timeout=None)
    
    try:
        if body is not None:
            req = client.build_request(request.method, target_url, headers=fwd_headers, json=body)
        else:
            req = client.build_request(request.method, target_url, headers=fwd_headers, content=request.stream())
            
        response = await client.send(req, stream=True)
        
        async def stream_generator():
            async for chunk in response.aiter_bytes():
                yield chunk
                
        return StreamingResponse(
            stream_generator(),
            status_code=response.status_code,
            headers=dict(response.headers)
        )
    except httpx.HTTPStatusError as e:
        sys.stderr.write(f"HTTP error from {target_url}: {e.response.status_code}\\n")
        return openai_error(f"Upstream provider returned HTTP {e.response.status_code}", "upstream_error", 502)
    except Exception as e:
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
    func updateRoutingTable(_ routes: [String: Int]) {
        let fm = FileManager.default
        let lengtaDir = fm.homeDirectoryForCurrentUser.appendingPathComponent(".lengtamlx")
        try? fm.createDirectory(at: lengtaDir, withIntermediateDirectories: true)
        
        let routesFile = lengtaDir.appendingPathComponent("routes.json")
        if let data = try? JSONSerialization.data(withJSONObject: routes) {
            try? data.write(to: routesFile)
        }
    }
}
