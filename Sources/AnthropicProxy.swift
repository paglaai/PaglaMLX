import Foundation
import Observation
import AppKit

/// Manages a FastAPI Python script that acts as a translation proxy,
/// converting Anthropic Messages API requests to OpenAI Chat Completions,
/// and translating the SSE stream back to Anthropic's format.
@MainActor
@Observable final class AnthropicProxy {
    static let shared = AnthropicProxy()
    
    var isRunning = false
    var port: Int
    
    private var process: Process?
    
    private init() {
        self.port = SettingsManager.shared.port + 1 // Default to Gateway Port + 1
    }
    
    func toggle() { isRunning ? stop() : start() }
    
    func start() {
        let settings = SettingsManager.shared
        guard !settings.pythonPath.isEmpty else { return }
        
        let script = """
import os, sys, json, httpx, asyncio
from fastapi import FastAPI, Request, Response
from fastapi.responses import StreamingResponse
import uvicorn

app = FastAPI(title="PaglaMLX Anthropic Proxy")

API_KEY = sys.argv[4] if len(sys.argv) > 4 else ""

@app.middleware("http")
async def check_auth(request: Request, call_next):
    if API_KEY and request.method != "OPTIONS":
        auth = request.headers.get("authorization", "")
        if auth != f"Bearer {API_KEY}" and request.headers.get("x-api-key", "") != API_KEY:
            return Response(content="Unauthorized", status_code=401)
    return await call_next(request)

TARGET_URL = ""

@app.post("/v1/messages")
async def messages(request: Request):
    try:
        body = await request.json()
    except:
        return Response(content="Invalid JSON", status_code=400)
        
    # Translate Anthropic to OpenAI
    openai_payload = {
        "model": body.get("model", "default"),
        "messages": body.get("messages", []),
        "stream": body.get("stream", False),
    }
    
    if "system" in body:
        # Prepend system message
        openai_payload["messages"].insert(0, {"role": "system", "content": body["system"]})
        
    if "max_tokens" in body:
        openai_payload["max_tokens"] = body["max_tokens"]
    if "temperature" in body:
        openai_payload["temperature"] = body["temperature"]
    if "top_p" in body:
        openai_payload["top_p"] = body["top_p"]
    if "top_k" in body:
        openai_payload["top_k"] = body["top_k"]
    if "stop_sequences" in body:
        openai_payload["stop"] = body["stop_sequences"]
        
    client = httpx.AsyncClient(timeout=None)
    
    headers = {"Content-Type": "application/json"}
    if API_KEY:
        headers["Authorization"] = f"Bearer {API_KEY}"
    
    if openai_payload["stream"]:
        req = client.build_request("POST", TARGET_URL, headers=headers, json=openai_payload)
        response = await client.send(req, stream=True)
        
        async def stream_generator():
            # Anthropic preamble
            yield b'event: message_start\\ndata: {"type":"message_start","message":{"id":"msg_123","type":"message","role":"assistant","content":[],"model":"'+body.get("model", "mlx").encode()+b'","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":0,"output_tokens":0}}}\\n\\n'
            yield b'event: content_block_start\\ndata: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}\\n\\n'
            
            async for line in response.aiter_lines():
                if not line or line.startswith("data: [DONE]"):
                    continue
                if line.startswith("data: "):
                    try:
                        data = json.loads(line[6:])
                        if "choices" in data and len(data["choices"]) > 0:
                            delta = data["choices"][0].get("delta", {})
                            content = delta.get("content", "")
                            if content:
                                out = {
                                    "type": "content_block_delta",
                                    "index": 0,
                                    "delta": {"type": "text_delta", "text": content}
                                }
                                yield f'event: content_block_delta\\ndata: {json.dumps(out)}\\n\\n'.encode()
                                
                            finish_reason = data["choices"][0].get("finish_reason")
                            if finish_reason:
                                reason = "end_turn" if finish_reason == "stop" else finish_reason
                                yield b'event: content_block_stop\\ndata: {"type":"content_block_stop","index":0}\\n\\n'
                                yield f'event: message_delta\\ndata: {{"type":"message_delta","delta":{{"stop_reason":"{reason}","stop_sequence":null}},"usage":{{"output_tokens":0}}}}\\n\\n'.encode()
                                yield b'event: message_stop\\ndata: {"type":"message_stop"}\\n\\n'
                    except:
                        pass
                        
        return StreamingResponse(
            stream_generator(),
            media_type="text/event-stream"
        )
    else:
        # Non-streaming
        response = await client.post(TARGET_URL, headers=headers, json=openai_payload)
        if response.status_code != 200:
            return Response(content=response.text, status_code=response.status_code)
            
        data = response.json()
        content = ""
        if "choices" in data and len(data["choices"]) > 0:
            content = data["choices"][0].get("message", {}).get("content", "")
            
        anthropic_response = {
            "id": data.get("id", "msg_123"),
            "type": "message",
            "role": "assistant",
            "content": [{"type": "text", "text": content}],
            "model": body.get("model", "mlx"),
            "stop_reason": "end_turn",
            "stop_sequence": None,
            "usage": {
                "input_tokens": data.get("usage", {}).get("prompt_tokens", 0),
                "output_tokens": data.get("usage", {}).get("completion_tokens", 0)
            }
        }
        return Response(content=json.dumps(anthropic_response), media_type="application/json")

if __name__ == "__main__":
    port = int(sys.argv[1])
    host = sys.argv[2]
    TARGET_URL = sys.argv[3]
    uvicorn.run(app, host=host, port=port, log_level="warning")
"""
        let fm = FileManager.default
        let lengtaDir = fm.homeDirectoryForCurrentUser.appendingPathComponent(".lengtamlx")
        try? fm.createDirectory(at: lengtaDir, withIntermediateDirectories: true)
        let scriptPath = lengtaDir.appendingPathComponent("anthropic_proxy.py").path
        try? script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
        
        let p = Process()
        p.executableURL = URL(fileURLWithPath: settings.pythonPath)
        
        let targetURL = "http://127.0.0.1:\(settings.port)/v1/chat/completions"
        p.arguments = [scriptPath, "\(self.port)", settings.host, targetURL, settings.apiKey]
        
        var env = ProcessInfo.processInfo.environment
        let extraPaths = "/Library/Frameworks/Python.framework/Versions/3.14/bin"
                       + ":/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        env["PATH"] = extraPaths + ":" + (env["PATH"] ?? "")
        p.environment = env
        
        p.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isRunning = false
            }
        }
        
        do {
            try p.run()
            self.process = p
            self.isRunning = true
        } catch {
            print("Failed to start Anthropic Proxy: \(error)")
        }
    }
    
    func stop() {
        process?.terminate()
        process = nil
        isRunning = false
    }
}
