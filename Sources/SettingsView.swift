import SwiftUI
import AppKit

struct SettingsView: View {
    @Environment(SettingsManager.self) var settings
    @Environment(ModelOrchestrator.self) var orchestrator
    @Environment(TunnelManager.self) var tunnel
    @State var integration = IntegrationManager.shared

    var body: some View {
        @Bindable var settings = settings
        @Bindable var orchestrator = orchestrator
        @Bindable var tunnel = tunnel
        @Bindable var integration = integration
        TabView(selection: $settings.lastSettingsTab) {
            
            // MARK: 1. Python
            Form {
                Section(header: Text("Python Environment").font(.headline)) {
                    Text("The Python executable must have `mlx_lm` installed.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField("Path", text: $settings.pythonPath)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Browse…") {
                            let panel = NSOpenPanel()
                            panel.canChooseDirectories = false
                            panel.canChooseFiles = true
                            panel.allowsMultipleSelection = false
                            panel.treatsFilePackagesAsDirectories = false
                            if panel.runModal() == .OK, let url = panel.url {
                                settings.pythonPath = url.path
                                orchestrator.detectPython()
                            }
                        }
                    }
                    
                    HStack {
                        Button("Auto-Detect") {
                            orchestrator.detectPython()
                        }
                        
                        if settings.pythonStatus.isChecking {
                            ProgressView().controlSize(.small)
                                .padding(.leading, 8)
                        } else {
                            Image(systemName: settings.pythonStatus.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(settings.pythonStatus.isValid ? .green : .red)
                                .symbolRenderingMode(.hierarchical)
                                .padding(.leading, 8)
                            
                            Text(settings.pythonStatus.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
            }
            .padding(20)
            .tabItem {
                Label("Python", systemImage: "terminal")
            }
            .tag(0)
            
            // MARK: 2. Server (Parameters)
            ScrollView {
            Form {
                Section(header: Text("Generation Parameters").font(.headline)) {
                    HStack {
                        Picker("Apply Preset", selection: Binding<UUID?>(
                            get: { settings.presets.first(where: {
                                $0.temp == settings.temp &&
                                $0.topP == settings.topP &&
                                $0.topK == settings.topK &&
                                $0.minP == settings.minP &&
                                $0.maxTokens == settings.maxTokens &&
                                $0.chatTemplateArgs == settings.chatTemplateArgs
                            })?.id },
                            set: { id in
                                guard let id = id else { return }
                                if let p = settings.presets.first(where: { $0.id == id }) {
                                    settings.temp = p.temp
                                    settings.topP = p.topP
                                    settings.topK = p.topK
                                    settings.minP = p.minP
                                    settings.maxTokens = p.maxTokens
                                    settings.chatTemplateArgs = p.chatTemplateArgs
                                }
                            }
                        )) {
                            Text("Custom").tag(nil as UUID?)
                            ForEach(settings.presets) { p in
                                Text(p.name).tag(p.id as UUID?)
                            }
                        }
                        .frame(maxWidth: 250)
                        Spacer()
                    }
                    .padding(.bottom, 8)
                    
                    VStack(alignment: .leading) {
                        Slider(value: $settings.temp, in: 0...2, step: 0.1) {
                            Text("Temperature")
                        } minimumValueLabel: { Text("0") } maximumValueLabel: { Text("2") }
                        Text("Value: \(settings.temp, specifier: "%.1f")").font(.caption).foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading) {
                        Slider(value: $settings.topP, in: 0...1, step: 0.05) {
                            Text("Top P")
                        } minimumValueLabel: { Text("0") } maximumValueLabel: { Text("1") }
                        Text("Value: \(settings.topP, specifier: "%.2f")").font(.caption).foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading) {
                        Slider(value: $settings.minP, in: 0...1, step: 0.05) {
                            Text("Min P")
                        } minimumValueLabel: { Text("0") } maximumValueLabel: { Text("1") }
                        Text("Value: \(settings.minP, specifier: "%.2f")").font(.caption).foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Top K:")
                        TextField("Top K", value: $settings.topK, formatter: NumberFormatter())
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        Text("(0 to disable)").font(.caption).foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Max Tokens:")
                        TextField("Max Tokens", value: $settings.maxTokens, formatter: NumberFormatter())
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                }
                
                Divider().padding(.vertical)
                
                Section(header: Text("Server Flags").font(.headline)) {
                    Picker("Log Level", selection: $settings.logLevel) {
                        ForEach(SettingsManager.LogLevel.allCases) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    
                    Toggle("Trust Remote Code", isOn: $settings.trustRemoteCode)
                    
                    VStack(alignment: .leading) {
                        Text("Chat Template Args (JSON)")
                        TextEditorView(text: $settings.chatTemplateArgs)
                            .frame(height: 60)
                    }
                }
            }
            }
            .padding(20)
            .tabItem {
                Label("Server", systemImage: "slider.horizontal.3")
            }
            .tag(1)
            
            // MARK: 3. Network & Remote
            Form {
                Section(header: Text("Network Configuration").font(.headline)) {
                    HStack {
                        Text("Gateway Port:")
                        TextField("Port", value: $settings.port, formatter: NumberFormatter())
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        Text("(Requires restart)").font(.caption).foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Bind Host:")
                        TextField("Host (127.0.0.1, 0.0.0.0, etc)", text: $settings.host)
                            .textFieldStyle(.roundedBorder)
                    }
                    Text("Use 0.0.0.0 or your Tailscale IP to expose the server to your network.")
                        .font(.caption).foregroundColor(.secondary)
                    
                    HStack {
                        Text("CORS Origins:")
                        TextField("*, http://localhost:3000", text: $settings.allowedOrigins)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    HStack {
                        Text("API Key:")
                        SecureField("Optional Bearer Token", text: $settings.apiKey)
                            .textFieldStyle(.roundedBorder)
                        Button("Rotate") {
                            settings.apiKey = "sk-mlx-" + UUID().uuidString.lowercased()
                        }
                    }
                    Text("Secures Gateway and Proxies (highly recommended if using Cloudflare).")
                        .font(.caption).foregroundColor(.secondary)
                }
                
                Divider().padding(.vertical)
                
                Section(header: Text("Cloudflare Tunnel").font(.headline)) {
                    Toggle("Enable Cloudflare Tunnel", isOn: $tunnel.isEnabled)
                    Text("Automatically creates a public trycloudflare.com URL for remote access.")
                        .font(.caption).foregroundColor(.secondary)
                    
                    if let err = tunnel.errorMessage {
                        Text(err).font(.caption).foregroundColor(.red)
                    }
                }
            }
            .padding(20)
            .tabItem {
                Label("Network", systemImage: "network")
            }
            .tag(2)
            
            // MARK: 4. Cache (KV)
            Form {
                Section(header: Text("In-Memory KV Caching").font(.headline)) {
                    HStack {
                        Text("Prompt Cache Size:")
                        TextField("Size", value: $settings.promptCacheSize, formatter: NumberFormatter())
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                        Text("(slots, 0 = default)").font(.caption).foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Prompt Cache Bytes:")
                        TextField("Bytes", value: $settings.promptCacheBytes, formatter: NumberFormatter())
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                        Text("(0 = unlimited)").font(.caption).foregroundColor(.secondary)
                    }
                    
                    Text("Warning: Very large KV caches can trigger macOS Jetsam OOM kills on unified memory systems if physical RAM is exhausted.")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.top, 4)
                }
            }
            .padding(20)
            .tabItem {
                Label("Cache", systemImage: "memorychip")
            }
            .tag(3)
            
            // MARK: 5. Prompt
            Form {
                Section(header: Text("Model Persona").font(.headline)) {
                    HStack {
                        Picker("Select Persona", selection: Binding<UUID?>(
                            get: { settings.personas.first(where: { $0.systemPrompt == settings.systemPrompt })?.id },
                            set: { id in
                                guard let id = id else { return }
                                if let p = settings.personas.first(where: { $0.id == id }) {
                                    settings.systemPrompt = p.systemPrompt
                                }
                            }
                        )) {
                            Text("Custom").tag(nil as UUID?)
                            ForEach(settings.personas) { p in
                                Text(p.name).tag(p.id as UUID?)
                            }
                        }
                        .frame(maxWidth: 250)
                        Spacer()
                    }
                    
                    Text("Note: mlx_lm does not natively accept a global system prompt via CLI, but clients will receive it. (Future versions of Gateway will inject this into external routes).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextEditorView(text: $settings.systemPrompt)
                        .frame(minHeight: 150)
                }
            }
            .padding(20)
            .tabItem {
                Label("Prompt", systemImage: "text.quote")
            }
            .tag(4)
            
            // MARK: 6. App
            Form {
                Section(header: Text("App Behaviour").font(.headline)) {
                    Toggle("Menu Bar Only Mode", isOn: $settings.menuBarMode)
                    
                    if settings.menuBarMode {
                        Toggle("Hide Dock Icon", isOn: $settings.hideDockIcon)
                            .padding(.leading, 20)
                    }
                    
                    Divider().padding(.vertical)
                    
                    HStack {
                        Text("Models Directory:")
                        TextField("Path", text: $settings.modelsDirectory)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Browse…") {
                            let panel = NSOpenPanel()
                            panel.canChooseDirectories = true
                            panel.canChooseFiles = false
                            panel.allowsMultipleSelection = false
                            if panel.runModal() == .OK, let url = panel.url {
                                settings.modelsDirectory = url.path
                            }
                        }
                    }
                    Text("Must contain GGUF, SafeTensors, or PyTorch models in subdirectories.")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .padding(20)
            .tabItem {
                Label("App", systemImage: "gearshape")
            }
            .tag(5)
            
            // MARK: 7. Cloud / BYOK
            ScrollView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        ProviderRow(label: "Free Router", placeholder: "sk-or-... (free, no card needed)", key: $settings.freeRouterKey)

                        Text("Set your OpenRouter API key here. When you send \"model=free\", PaglaMLX routes through OpenRouter — they pick the cheapest capable model for your request. Get a free key at openrouter.ai/keys (no credit card required).")
                            .font(.custom("Lucida Grande", size: 12))
                            .foregroundColor(Color(hex: "#a0a0a0"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } header: {
                    Text("Free Router — Powered by OpenRouter")
                        .font(.custom("Lucida Grande", size: 14.95))
                }

                Section {
                    VStack(spacing: 1) {
                        ProviderRow(label: "OpenAI",     placeholder: "sk-proj-...", key: $settings.openaiKey)
                        divider
                        ProviderRow(label: "Anthropic",  placeholder: "sk-ant-...",  key: $settings.anthropicKey)
                        divider
                        ProviderRow(label: "Gemini",     placeholder: "AIza...",     key: $settings.geminiKey)
                    }
                    .padding(.vertical, 4)

                    Text("Prefix your model name with \"gpt-\", \"claude-\", or \"gemini-\" to route directly.")
                        .font(.custom("Lucida Grande", size: 13))
                        .foregroundColor(Color(hex: "#a0a0a0"))
                } header: {
                    Text("Direct API Keys")
                        .font(.custom("Lucida Grande", size: 14.95))
                }

                Section {
                    VStack(spacing: 1) {
                        ProviderRow(label: "OpenRouter", placeholder: "sk-or-...", key: $settings.openrouterKey)
                    }
                    .padding(.vertical, 4)

                    Text("Prefix with \"openrouter/\" to pick a specific model. For automatic cheapest routing, use the Free Router key above with \"model=free\".")
                        .font(.custom("Lucida Grande", size: 13))
                        .foregroundColor(Color(hex: "#a0a0a0"))
                } header: {
                    Text("Advanced: OpenRouter (Direct)")
                        .font(.custom("Lucida Grande", size: 14.95))
                }

                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 10) {
                            keyDot(true)
                            Text("Key set").font(.custom("Lucida Grande", size: 13))
                            keyDot(false)
                            Text("Key empty").font(.custom("Lucida Grande", size: 13))
                        }
                        .foregroundColor(Color(hex: "#a0a0a0"))

                        Text("model=\"auto\" uses heuristic engine: VLM for images → context-fit scoring → keyword intent (code/math/reasoning) → best local model. model=\"free\" routes through Free Router (OpenRouter).")
                            .font(.custom("Lucida Grande", size: 13))
                            .foregroundColor(Color(hex: "#a0a0a0"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } header: {
                    Text("Routing Behaviour")
                        .font(.custom("Lucida Grande", size: 14.95))
                }
            }
            }
            .font(.custom("Lucida Grande", size: 13))
            .padding(20)
            .tabItem {
                Label("Cloud", systemImage: "cloud.fill")
            }
            .tag(6)
            // MARK: 8. Integrations
            Form {
                Section(header: Text("Auto-Configure Clients").font(.headline)) {
                    Text("Click 'Apply' to automatically set the local proxy URL and API key in the configuration files of these clients.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    List(integration.targets) { target in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(target.name).font(.subheadline).bold()
                                Text(target.configPath).font(.caption2).foregroundColor(.secondary)
                            }
                            Spacer()
                            
                            if let status = integration.statuses[target.id] {
                                Text(status)
                                    .font(.caption)
                                    .foregroundColor(status.contains("✓") ? .green : .red)
                            }
                            
                            Button("Apply") {
                                let port = settings.port
                                integration.applyIntegration(for: target, port: port, apiKey: settings.apiKey)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 2)
                    }
                    .frame(height: 250)
                }
            }
            .padding(20)
            .tabItem {
                Label("Integrations", systemImage: "link")
            }
            .tag(7)
            
            // MARK: 9. API Details
            ApiDetailsTab(host: settings.host, port: settings.port, apiKey: settings.apiKey, allowedOrigins: settings.allowedOrigins, freeRouterEnabled: settings.freeRouterEnabled)
                .padding(20)
                .tabItem {
                    Label("API Details", systemImage: "doc.text.magnifyingglass")
                }
                .tag(8)
            
        }
        .frame(width: 640, height: 520)
    }
}

// MARK: - API Details Tab

private struct ApiDetailsTab: View {
    let host: String
    let port: Int
    let apiKey: String
    let allowedOrigins: String
    let freeRouterEnabled: Bool
    
    @State private var copied: String?
    
    private var baseURL: String { "http://\(host):\(port)" }
    private var apiBase: String { "\(baseURL)/v1" }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // 1. Connection Details
                GroupBox(label: Label("Connection Details", systemImage: "network").font(.headline)) {
                    VStack(alignment: .leading, spacing: 8) {
                        copyRow("Base URL", apiBase)
                        copyRow("API Key", apiKey)
                        copyRow("CORS Origins", allowedOrigins)
                    }
                    .padding(.vertical, 4)
                }
                
                // 2. Endpoints
                GroupBox(label: Label("Available Endpoints", systemImage: "list.bullet").font(.headline)) {
                    VStack(alignment: .leading, spacing: 4) {
                        endpointRow("POST", "\(apiBase)/chat/completions", "OpenAI Chat")
                        endpointRow("POST", "\(apiBase)/messages", "Anthropic Messages")
                        endpointRow("GET",  "\(apiBase)/models", "List loaded models")
                        endpointRow("GET",  "\(baseURL)/", "Health check")
                    }
                    .padding(.vertical, 4)
                }
                
                // 3. curl Examples
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
                
                // 4. Provider Configs
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
                        
                        providerBlock("VS Code (Cline / Kilo)") {
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
                    }
                    .padding(.vertical, 4)
                }
                
                // 5. Routing Table
                GroupBox(label: Label("Routing Table", systemImage: "arrow.triangle.branch").font(.headline)) {
                    VStack(alignment: .leading, spacing: 4) {
                        routeRow("auto", "Heuristic engine: VLM → context → intent → best local")
                        routeRow("free", "OpenRouter auto (Free Router)")
                        routeRow("gpt-* / o1 / o3", "OpenAI API")
                        routeRow("claude-*", "Anthropic API")
                        routeRow("gemini-*", "Gemini API")
                        routeRow("openrouter/*", "OpenRouter (direct)")
                    }
                    .padding(.vertical, 4)
                }
                
                // 6. Troubleshooting
                GroupBox(label: Label("Troubleshooting", systemImage: "wrench").font(.headline)) {
                    VStack(alignment: .leading, spacing: 4) {
                        tipRow("Connection refused", "Gateway is not running. Press Play on a model first.")
                        tipRow("401 Unauthorized", "Wrong API key. Check Settings → Network.")
                        tipRow("503 Not found", "Model name not recognised. Use \"auto\".")
                        tipRow("CORS error", "Set CORS Origins to \"*\" in Settings → Network.")
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private var apiKeyHeader: String {
        apiKey.isEmpty ? "" : #"-H "Authorization: Bearer \#(apiKey)""#
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
            Text(method).font(.system(.caption2, design: .monospaced)).foregroundColor(method == "GET" ? .green : .orange).frame(width: 38)
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
            Text(prefix).font(.system(.caption, design: .monospaced)).frame(width: 100, alignment: .leading)
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
                .foregroundColor(copied == text ? .green : .secondary)
                .font(.caption)
        }
        .buttonStyle(.plain)
        .help("Copy")
    }
}

// MARK: - Design System Helpers

private struct ProviderRow: View {
    let label: String
    let placeholder: String
    @Binding var key: String

    var body: some View {
        HStack(spacing: 6) {
            keyDot(!key.isEmpty)
                .frame(width: 6)

            Text(label + ":")
                .font(.custom("Lucida Grande", size: 13))
                .foregroundColor(Color(hex: "#000000"))
                .frame(width: 82, alignment: .trailing)

            SecureField(placeholder, text: $key)
                .font(.custom("Lucida Grande", size: 13))
                .textFieldStyle(.plain)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color(hex: "#ffffff"))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color(hex: "#ebeef1"), lineWidth: 1)
                )
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 3)
    }
}

private var divider: some View {
    Divider().overlay(Color(hex: "#ebeef1"))
}

private func keyDot(_ filled: Bool) -> some View {
    Circle()
        .fill(filled ? Color(hex: "#3366cc") : Color(hex: "#ebeef1"))
        .frame(width: 6, height: 6)
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
