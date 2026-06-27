import Foundation
import Combine
import AppKit

/// Manages a FastAPI-based Python HTTP reverse proxy that routes requests
/// to the correct `mlx_lm.server` instance based on the requested model name.
@MainActor
final class RoutingGateway: ObservableObject {
    static let shared = RoutingGateway()
    
    @Published var isRunning = false
    @Published var port: Int
    @Published var recentErrors: [String] = []
    
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
import os, sys, json, httpx, asyncio
from fastapi import FastAPI, Request, Response
from fastapi.responses import StreamingResponse
import uvicorn

app = FastAPI(title="PaglaMLX Routing Gateway")

API_KEY = os.environ.get("LENGTA_API_KEY", "")
OR_KEY = os.environ.get("OPENROUTER_KEY", "")
ANT_KEY = os.environ.get("ANTHROPIC_KEY", "")
OAI_KEY = os.environ.get("OPENAI_KEY", "")
GEM_KEY = os.environ.get("GEMINI_KEY", "")
FREE_ROUTER = os.environ.get("FREE_ROUTER_ENABLED", "false").lower() == "true"

ROUTING_FILE = os.path.expanduser("~/.lengtamlx/routes.json")

# Session routing state for stickiness
session_routes = {}

@app.middleware("http")
async def check_auth(request: Request, call_next):
    if API_KEY and request.method != "OPTIONS":
        auth = request.headers.get("authorization", "")
        if auth != f"Bearer {API_KEY}":
            return Response(content="Unauthorized", status_code=401)
    return await call_next(request)

def get_local_routes():
    try:
        with open(ROUTING_FILE, "r") as f:
            return json.load(f)
    except:
        return {}

def get_session_id(request: Request):
    return request.headers.get("x-session-id") or request.headers.get("authorization", "default")

@app.api_route("/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "OPTIONS", "HEAD", "PATCH"])
async def proxy(request: Request, path: str):
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
        
        if name_lower.startswith("gpt-") or name_lower.startswith("o1") or name_lower.startswith("o3"):
            if OAI_KEY:
                target_url = f"https://api.openai.com/{path}"
                fwd_headers["authorization"] = f"Bearer {OAI_KEY}"
                
        elif name_lower.startswith("claude-"):
            if ANT_KEY:
                # Assuming this is going to AnthropicProxy or direct OpenAI-compatible endpoint.
                # If going direct to Anthropic API, it might need translation, but we have an AnthropicProxy for the other direction.
                # For now, just route assuming the client is using OpenAI format and the target accepts it.
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
        return Response(content="No route available", status_code=503)
        
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
        return Response(content=f"Upstream HTTP error: {e.response.status_code}", status_code=502)
    except Exception as e:
        sys.stderr.write(f"Proxy error connecting to {target_url}: {str(e)}\\n")
        return Response(content=f"Proxy error: {str(e)}", status_code=502)

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
        env["FREE_ROUTER_ENABLED"] = settings.freeRouterEnabled ? "true" : "false"
        
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
