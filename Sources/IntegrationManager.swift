import Foundation
import Observation
import Combine

struct IntegrationTarget: Identifiable {
    let id = UUID()
    let name: String
    let configPath: String
    let integrationType: IntegrationType
    
    enum IntegrationType {
        case vsCodeSettings
        case continueDev
        case claudeCode
        case claudeDesktop
        case opencodeStandalone
        case codex
        case genericJSON(keyPath: String)
    }
}

@MainActor
@Observable final class IntegrationManager {
    static let shared = IntegrationManager()
    
    var targets: [IntegrationTarget] = [
        IntegrationTarget(name: "VS Code Co-Pilot", configPath: "~/Library/Application Support/Code/User/settings.json", integrationType: .vsCodeSettings),
        IntegrationTarget(name: "VS Code / Kilo Code", configPath: "~/Library/Application Support/Code/User/settings.json", integrationType: .vsCodeSettings),
        IntegrationTarget(name: "VS Code / OpenCode", configPath: "~/Library/Application Support/Code/User/settings.json", integrationType: .vsCodeSettings),
        IntegrationTarget(name: "Cline Code", configPath: "~/Library/Application Support/Code/User/settings.json", integrationType: .vsCodeSettings),
        IntegrationTarget(name: "Claude Code (VS Code)", configPath: "~/Library/Application Support/Code/User/settings.json", integrationType: .vsCodeSettings),
        IntegrationTarget(name: "Continue.dev", configPath: "~/.continue/config.json", integrationType: .continueDev),
        IntegrationTarget(name: "Claude Code", configPath: "~/.claude.json", integrationType: .claudeCode),
        IntegrationTarget(name: "Claude Desktop", configPath: "~/Library/Application Support/Claude/claude_desktop_config.json", integrationType: .claudeDesktop),
        IntegrationTarget(name: "Agent Hermes", configPath: "~/.hermes/config.json", integrationType: .genericJSON(keyPath: "apiBase")),
        IntegrationTarget(name: "OpenClaw", configPath: "~/.openclaw/config.json", integrationType: .genericJSON(keyPath: "apiBase")),
        IntegrationTarget(name: "Qwen Code", configPath: "~/.qwen/config.json", integrationType: .genericJSON(keyPath: "apiBase")),
        IntegrationTarget(name: "OpenCode (Legacy)", configPath: "~/.opencode/config.json", integrationType: .genericJSON(keyPath: "apiBase")),
        IntegrationTarget(name: "OpenCode (Standalone)", configPath: "~/.config/opencode/opencode.json", integrationType: .opencodeStandalone),
        IntegrationTarget(name: "Codex CLI", configPath: "~/.codex/config.toml", integrationType: .codex)
    ]
    
    var statuses: [UUID: String] = [:]
    
    private init() {}
    
    func applyIntegration(for target: IntegrationTarget, port: Int, apiKey: String) {
        let settings = SettingsManager.shared
        guard !settings.pythonPath.isEmpty else {
            statuses[target.id] = "Error: Python path not set"
            return
        }
        
        statuses[target.id] = "Applying..."
        
        let expandedPath = NSString(string: target.configPath).expandingTildeInPath
        let baseURL = "http://127.0.0.1:\(port)/v1"
        
        let script = """
import sys
import json
import os
import re
import shutil

file_path = sys.argv[1]
integration_type = sys.argv[2]
base_url = sys.argv[3]
api_key = sys.argv[4]

def strip_comments(json_string):
    json_string = re.sub(r'(?m)^\\s*//.*$', '', json_string)
    json_string = re.sub(r'(?s)/\\*.*?\\*/', '', json_string)
    return json_string

if not os.path.exists(file_path):
    os.makedirs(os.path.dirname(file_path), exist_ok=True)
    content = "{}"
else:
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    shutil.copyfile(file_path, file_path + ".bak")

try:
    content = strip_comments(content)
    data = json.loads(content if content.strip() else "{}")
except Exception as e:
    print(f"Failed to parse JSON: {e}")
    sys.exit(1)

def apply_vscode():
    adv = data.get("github.copilot.advanced", {})
    adv["debug.overrideProxyUrl"] = base_url.replace("/v1", "")
    adv["debug.chatOverrideProxyUrl"] = base_url + "/chat/completions"
    data["github.copilot.advanced"] = adv
    
    data["kilo-code.new.apiBaseUrl"] = base_url
    data["kilo-code.new.apiKey"] = api_key
    
    data["opencode.apiBase"] = base_url
    data["opencode.apiKey"] = api_key
    
    data["cline.apiBase"] = base_url
    data["cline.apiKey"] = api_key
    
    data["claude-code.apiBase"] = base_url
    data["claude-code.apiKey"] = api_key

def apply_continue():
    models = data.get("models", [])
    found = False
    for m in models:
        if m.get("title") == "PaglaMLX":
            m["apiBase"] = base_url
            m["apiKey"] = api_key
            found = True
            break
    if not found:
        models.append({
            "title": "PaglaMLX",
            "provider": "openai",
            "model": "AUTODETECT",
            "apiBase": base_url,
            "apiKey": api_key
        })
    data["models"] = models

def apply_claude():
    endpoints = data.get("customApiEndpoints", {})
    endpoints["lengta"] = {
        "url": base_url,
        "key": api_key
    }
    data["customApiEndpoints"] = endpoints
    data["primaryModel"] = "lengta"

def apply_generic(key_path):
    data[key_path] = base_url
    data["apiKey"] = api_key

def apply_claude_desktop():
    env = data.get("env", {})
    env["ANTHROPIC_BASE_URL"] = base_url
    env["ANTHROPIC_API_KEY"] = api_key
    data["env"] = env

def apply_opencode():
    providers = data.get("provider", {})
    providers["lengtamlx"] = {
        "name": "PaglaMLX",
        "npm": "@ai-sdk/openai-compatible",
        "options": {
            "baseURL": base_url,
            "apiKey": api_key
        },
        "models": {
            "default": {
                "name": "Local Model"
            }
        }
    }
    data["provider"] = providers

def apply_codex():
    toml = f\"\"\"model = "auto"
model_provider = "lengtamlx"

[model_providers.lengtamlx]
name = "PaglaMLX"
base_url = "{base_url}"
env_key = "OPENAI_API_KEY"
wire_api = "responses"
\"\"\"
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(toml)
    print("SUCCESS")
    sys.exit(0)

if integration_type == "vsCodeSettings":
    apply_vscode()
elif integration_type == "continueDev":
    apply_continue()
elif integration_type == "claudeCode":
    apply_claude()
elif integration_type == "claudeDesktop":
    apply_claude_desktop()
elif integration_type == "opencodeStandalone":
    apply_opencode()
elif integration_type == "codex":
    apply_codex()
elif integration_type.startswith("genericJSON"):
    key = integration_type.split(":")[1]
    apply_generic(key)

# Codex writes TOML directly and exits in apply_codex()
if integration_type != "codex":
    try:
        with open(file_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=4)
        print("SUCCESS")
    except Exception as e:
        print(f"Error saving: {e}")
        sys.exit(1)
"""
        let fm = FileManager.default
        let lengtaDir = fm.homeDirectoryForCurrentUser.appendingPathComponent(".lengtamlx")
        try? fm.createDirectory(at: lengtaDir, withIntermediateDirectories: true)
        
        let scriptPath = lengtaDir.appendingPathComponent("integrator.py").path
        try? script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
        
        var typeArg = ""
        switch target.integrationType {
        case .vsCodeSettings: typeArg = "vsCodeSettings"
        case .continueDev: typeArg = "continueDev"
        case .claudeCode: typeArg = "claudeCode"
        case .claudeDesktop: typeArg = "claudeDesktop"
        case .opencodeStandalone: typeArg = "opencodeStandalone"
        case .codex: typeArg = "codex"
        case .genericJSON(let k): typeArg = "genericJSON:\(k)"
        }
        
        let p = Process()
        p.executableURL = URL(fileURLWithPath: settings.pythonPath)
        p.arguments = [scriptPath, expandedPath, typeArg, baseURL, apiKey]
        
        var env = ProcessInfo.processInfo.environment
        let extraPaths = "/Library/Frameworks/Python.framework/Versions/3.14/bin"
                       + ":/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        env["PATH"] = extraPaths + ":" + (env["PATH"] ?? "")
        p.environment = env
        
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        
        do {
            try p.run()
            p.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            if p.terminationStatus == 0 && output.contains("SUCCESS") {
                statuses[target.id] = "Configured ✓ (Backup created)"
            } else {
                statuses[target.id] = "Failed: \(output)"
            }
        } catch {
            statuses[target.id] = "Failed: \(error.localizedDescription)"
        }
    }
}
