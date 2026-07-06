import SwiftUI

struct ApiReferenceView: View {
    let host: String
    let port: Int
    let apiKey: String
    let allowedOrigins: String
    let freeRouterEnabled: Bool
    let temp: Double
    let topP: Double
    let topK: Int
    let minP: Double
    let maxTokens: Int
    let logLevel: String
    let trustRemoteCode: Bool
    let chatTemplateArgs: String
    let gatewayRunning: Bool
    let runningModels: [(name: String, port: Int, modelType: String)]

    @State private var copied: String?

    private var baseURL: String { "http://\(host):\(port)" }
    private var apiBase: String { "\(baseURL)/v1" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                serverStatusSection
                currentParamsSection
                connectionDetailsSection
                endpointsSection
                chatCompletionsSection
                messagesSection
                modelsSection
                quickTestSection
                providerConfigSection
                routingTableSection
                troubleshootingSection
            }
            .padding(20)
        }
    }

    // MARK: - 1. Server Status

    private var serverStatusSection: some View {
        GroupBox(label: Label("Server Status", systemImage: "antenna.radiowaves.left.and.right").font(.headline)) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Circle().fill(gatewayRunning ? DesignTokens.Color.success : DesignTokens.Color.error).frame(width: 8, height: 8)
                    Text(gatewayRunning ? "Gateway running on port \(port)" : "Gateway stopped")
                        .font(.caption).foregroundColor(gatewayRunning ? .primary : .secondary)
                    Spacer()
                }
                HStack {
                    Circle().fill(DesignTokens.Color.success).frame(width: 8, height: 8)
                    Text("CORS: ")
                        .font(.caption).foregroundColor(.secondary)
                    Text(allowedOrigins == "*" ? "Enabled (all origins)" : "Enabled (\(allowedOrigins))")
                        .font(.caption)
                    Spacer()
                }
                HStack {
                    Circle().fill(freeRouterEnabled ? DesignTokens.Color.success : DesignTokens.Color.secondaryText)
                        .frame(width: 8, height: 8)
                    Text("Free Router: ")
                        .font(.caption).foregroundColor(.secondary)
                    Text(freeRouterEnabled ? "Enabled" : "Disabled")
                        .font(.caption)
                    Spacer()
                }
                if !runningModels.isEmpty {
                    HStack(spacing: 4) {
                        Text("Active models:")
                            .font(.caption).foregroundColor(.secondary)
                        ForEach(Array(runningModels.enumerated()), id: \.offset) { i, m in
                            Text("\(m.name)")
                                .font(.system(size: 10, design: .monospaced))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(DesignTokens.Color.success.opacity(0.15))
                                .cornerRadius(3)
                        }
                        Spacer()
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - 2. Current Parameters

    private var currentParamsSection: some View {
        GroupBox(label: Label("Active Model Parameters", systemImage: "slider.horizontal.3").font(.headline)) {
            VStack(alignment: .leading, spacing: 4) {
                paramRow("Temperature", String(format: "%.1f", temp))
                paramRow("Top P", String(format: "%.2f", topP))
                paramRow("Top K", "\(topK)")
                paramRow("Min P", String(format: "%.2f", minP))
                paramRow("Max Tokens", "\(maxTokens)")
                paramRow("Log Level", logLevel)
                paramRow("Trust Remote Code", trustRemoteCode ? "Yes" : "No")
                if !chatTemplateArgs.isEmpty {
                    paramRow("Chat Template", chatTemplateArgs)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - 3. Connection Details

    private var connectionDetailsSection: some View {
        GroupBox(label: Label("Connection Details", systemImage: "network").font(.headline)) {
            VStack(alignment: .leading, spacing: 8) {
                copyRow("Base URL", apiBase)
                copyRow("API Key", apiKey)
                copyRow("Host", "\(host):\(port)")
                copyRow("CORS Origins", allowedOrigins)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - 4. Endpoints Overview

    private var endpointsSection: some View {
        GroupBox(label: Label("Available Endpoints", systemImage: "list.bullet").font(.headline)) {
            VStack(alignment: .leading, spacing: 4) {
                endpointRow("POST", "\(apiBase)/chat/completions", "OpenAI Chat Completions")
                endpointRow("POST", "\(apiBase)/messages", "Anthropic Messages (translated)")
                endpointRow("GET",  "\(apiBase)/models", "List loaded models")
                endpointRow("GET",  "\(baseURL)/health", "Health check")
                endpointRow("GET",  "\(baseURL)/", "Root health check")
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - 5. Chat Completions Reference

    private var chatCompletionsSection: some View {
        GroupBox(label: Label("POST /v1/chat/completions", systemImage: "bubble.left.and.bubble.right").font(.headline)) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Standard OpenAI-compatible endpoint. Accepts all common parameters.")
                    .font(.caption).foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Parameters").font(.caption).bold().padding(.bottom, 2)
                    paramRow("model", "string, required — Model name, \"auto\", or routing prefix")
                    paramRow("messages", "array, required — Message objects (system/user/assistant/tool)")
                    paramRow("temperature", "number, default \(String(format: "%.1f", temp))")
                    paramRow("top_p", "number, default \(String(format: "%.2f", topP))")
                    paramRow("top_k", "integer, default \(topK)")
                    paramRow("min_p", "number, default \(String(format: "%.2f", minP))")
                    paramRow("max_tokens", "integer, default \(maxTokens)")
                    paramRow("stream", "boolean, default false — SSE streaming")
                }

                Text("Non-streaming response").font(.caption).bold().padding(.top, 2)
                copyBlock(#"""
                {
                  "id": "chatcmpl-xxx",
                  "object": "chat.completion",
                  "choices": [{
                    "index": 0,
                    "message": {"role": "assistant", "content": "Hello!"},
                    "finish_reason": "stop"
                  }],
                  "usage": {"prompt_tokens": 12, "completion_tokens": 8, "total_tokens": 20}
                }
                """#)

                Text("Streaming (SSE)").font(.caption).bold().padding(.top, 2)
                copyBlock(#"""
                data: {"choices":[{"delta":{"role":"assistant"}}]}
                data: {"choices":[{"delta":{"content":"Hello"}}]}
                data: [DONE]
                """#)

                Text("curl example").font(.caption).bold().padding(.top, 2)
                copyBlock(#"curl \#(apiBase)/chat/completions \#(apiKeyHeader)"# + """
                 \
                  -H "Content-Type: application/json" \
                  -d '{"model":"auto","messages":[{"role":"user","content":"Hello"}],"stream":true}'
                """)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - 6. Messages (Anthropic) Reference

    private var messagesSection: some View {
        GroupBox(label: Label("POST /v1/messages", systemImage: "arrow.triangle.swap").font(.headline)) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Translates Anthropic-format requests to OpenAI and back, so Claude Desktop and other Anthropic-native clients can use local models.")
                    .font(.caption).foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Parameters").font(.caption).bold().padding(.bottom, 2)
                    paramRow("model", "string — Model name, \"auto\", or routing prefix")
                    paramRow("messages", "array — Anthropic-format messages")
                    paramRow("system", "string — System prompt (top-level field)")
                    paramRow("max_tokens", "integer — Required by Anthropic spec")
                    paramRow("stream", "boolean — SSE streaming")
                }

                Text("Content blocks (text, image) and tool calls translate bidirectionally:")
                    .font(.caption).foregroundColor(.secondary).padding(.top, 2)
                Text("Anthropic tool_use ↔ OpenAI tool_calls | Anthropic tool_result ↔ OpenAI tool role")
                    .font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)

                Text("curl example").font(.caption).bold().padding(.top, 2)
                copyBlock(#"curl \#(apiBase)/messages \#(apiKeyHeader)"# + """
                 \
                  -H "Content-Type: application/json" \
                  -d '{"model":"auto","max_tokens":1024,"messages":[{"role":"user","content":"Hello!"}]}'
                """)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - 7. Models Reference

    private var modelsSection: some View {
        GroupBox(label: Label("GET /v1/models", systemImage: "square.grid.2x2").font(.headline)) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Lists models currently loaded as mlx_lm.server processes plus available cloud models.")
                    .font(.caption).foregroundColor(.secondary)

                Text("Response").font(.caption).bold()
                copyBlock(#"""
                {
                  "object": "list",
                  "data": [
                    {"id": "Llama-3.2-3B-Instruct-4bit", "object": "model"},
                    {"id": "free", "object": "model"},
                    {"id": "gpt-4o", "object": "model"}
                  ]
                }
                """#)

                Text("curl example").font(.caption).bold().padding(.top, 2)
                copyBlock(#"curl \#(apiBase)/models \#(apiKeyHeader)"#)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - 8. Quick Test

    private var quickTestSection: some View {
        GroupBox(label: Label("Quick Test (curl)", systemImage: "terminal").font(.headline)) {
            VStack(alignment: .leading, spacing: 6) {
                copyBlock(#"curl \#(baseURL)/"#)
                Text("→ {\"status\":\"ok\"}").font(.caption).foregroundColor(.secondary)

                copyBlock(#"curl \#(apiBase)/chat/completions \#(apiKeyHeader)"# + """
                 \
                  -H "Content-Type: application/json" \
                  -d '{"model":"auto","messages":[{"role":"user","content":"Hello"}]}'
                """)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - 9. Provider Configs

    private var providerConfigSection: some View {
        GroupBox(label: Label("Custom Provider Config", systemImage: "square.and.pencil").font(.headline)) {
            VStack(alignment: .leading, spacing: 10) {
                providerBlock("OpenAI-Compatible Client") {
                    """
                    Base URL: \(apiBase)
                    API Key:  \(apiKey)
                    Model:    auto
                    """
                }

                providerBlock("VS Code (Copilot)") {
                    #"""
                    "github.copilot.advanced.debug.overrideProxyUrl": "\#(baseURL)",
                    "debug.chatOverrideProxyUrl": "\#(baseURL)"
                    """#
                }

                providerBlock("VS Code (Cline / Kilo / opencode)") {
                    #"""
                    "cline.apiBase": "\#(apiBase)",
                    "cline.apiKey": "\#(apiKey)",
                    "kilo.apiBase": "\#(apiBase)",
                    "kilo.apiKey": "\#(apiKey)",
                    "opencode.apiBase": "\#(apiBase)",
                    "opencode.apiKey": "\#(apiKey)"
                    """#
                }

                providerBlock("Continue.dev") {
                    #"""
                    {
                      "models": [{
                        "title": "PaglaMLX",
                        "provider": "openai",
                        "model": "AUTODETECT",
                        "apiBase": "\#(apiBase)",
                        "apiKey": "\#(apiKey)"
                      }]
                    }
                    """#
                }

                providerBlock("Claude Desktop") {
                    #"""
                    "env": {
                      "ANTHROPIC_BASE_URL": "\#(baseURL)",
                      "ANTHROPIC_API_KEY": "\#(apiKey)"
                    }
                    """#
                }

                providerBlock("OpenClaw") {
                    #"""
                    {
                      "models": {
                        "providers": {
                          "lengtamlx": {
                            "baseUrl": "\#(apiBase)",
                            "apiKey": "\#(apiKey)",
                            "api": "openai-completions"
                          }
                        }
                      }
                    }
                    """#
                }

                providerBlock("Agent Hermes") {
                    #"""
                    model:
                      provider: custom
                      models:
                        - name: PaglaMLX
                          model: auto
                          apiBase: \#(apiBase)
                          apiKey: \#(apiKey)
                    """#
                }

                providerBlock("Generic OpenAI SDK") {
                    #"""
                    from openai import OpenAI
                    client = OpenAI(
                        base_url="\#(apiBase)",
                        api_key="\#(apiKey)"
                    )
                    """#
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - 10. Routing Table

    private var routingTableSection: some View {
        GroupBox(label: Label("Routing Table", systemImage: "arrow.triangle.branch").font(.headline)) {
            VStack(alignment: .leading, spacing: 4) {
                Text("On every request, the gateway checks these in order:").font(.caption).foregroundColor(.secondary)
                    .padding(.bottom, 4)

                routeRow("Exact match", "~/.lengtamlx/routes.json key")
                routeRow("Substring", "local route key contains (or is in) model name")
                routeRow("auto", "Heuristic: VLM → context → intent → best local")
                routeRow("free", "Multi-provider failover chain (10 providers)")
                routeRow("gpt-* / o1 / o3", "OpenAI API")
                routeRow("claude-*", "Anthropic API")
                routeRow("gemini-*", "Gemini API")
                routeRow("openrouter/*", "OpenRouter (direct)")
                routeRow("Session stickiness", "Reuses this session's backend")
                routeRow("Local fallback", "First available local model")
                routeRow("503", "Nothing matched")
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - 11. Troubleshooting

    private var troubleshootingSection: some View {
        GroupBox(label: Label("Troubleshooting", systemImage: "wrench").font(.headline)) {
            VStack(alignment: .leading, spacing: 4) {
                tipRow("Connection refused", "Gateway is not running. Press Play on a model first.")
                tipRow("401 Unauthorized", "Wrong API key. Check Settings → Network.")
                tipRow("503 Not found", "Model name not recognised. Use \"auto\".")
                tipRow("CORS error", "Set CORS Origins to \"*\" in Settings → Network.")
                tipRow("Model not responding", "Check the model's logs in the Console tab.")
                tipRow("Out of memory", "Use a smaller quantized model (e.g., 4-bit).")
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Helpers

    private var apiKeyHeader: String {
        apiKey.isEmpty ? "" : #"-H "Authorization: Bearer \#(apiKey)""#
    }

    private func paramRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label + ":").font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary).frame(width: 100, alignment: .trailing)
            Text(value).font(.system(size: 10, design: .monospaced))
                .foregroundColor(.primary)
            Spacer()
        }
    }

    private func copyRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label + ":").font(.caption).foregroundColor(.secondary).frame(width: 80, alignment: .trailing)
            Text(value).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
            Spacer()
            copyButton(value)
        }
    }

    private func endpointRow(_ method: String, _ url: String, _ desc: String) -> some View {
        HStack(alignment: .top) {
            Text(method).font(.system(.caption2, design: .monospaced))
                .foregroundColor(method == "GET" ? DesignTokens.Color.success : .orange).frame(width: 38)
            Text(url).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
            Spacer()
            Text(desc).font(.caption2).foregroundColor(.secondary)
            copyButton(url)
        }
    }

    private func copyBlock(_ text: String) -> some View {
        HStack(alignment: .top) {
            Text(text).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                .padding(8)
                .background(Color(.textBackgroundColor))
                .cornerRadius(6)
            copyButton(text)
        }
    }

    private func providerBlock(_ name: String, content: () -> String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name).font(.caption).bold()
            HStack(alignment: .top) {
                Text(content()).font(.system(.caption2, design: .monospaced)).textSelection(.enabled)
                    .padding(8)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(6)
                copyButton(content())
            }
        }
    }

    private func routeRow(_ prefix: String, _ dest: String) -> some View {
        HStack {
            Text(prefix).font(.system(.caption, design: .monospaced)).frame(width: 130, alignment: .leading)
            Text("→").font(.caption).foregroundColor(.secondary)
            Text(dest).font(.caption).foregroundColor(.secondary)
        }
    }

    private func tipRow(_ issue: String, _ fix: String) -> some View {
        HStack(alignment: .top) {
            Text(issue + ":").font(.caption).bold().frame(width: 130, alignment: .trailing)
            Text(fix).font(.caption).foregroundColor(.secondary)
        }
    }

    private func copyButton(_ text: String) -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            copied = text
            Task { try? await Task.sleep(for: .seconds(1.5)); copied = nil }
        } label: {
            Image(systemName: copied == text ? "checkmark" : "doc.on.doc")
                .foregroundColor(copied == text ? DesignTokens.Color.success : .secondary)
                .font(.caption)
        }
        .buttonStyle(.plain)
        .help("Copy")
    }
}
