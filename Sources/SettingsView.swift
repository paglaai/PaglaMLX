import SwiftUI
import AppKit

struct SettingsView: View {
    @Environment(SettingsManager.self) var settings
    @Environment(ModelOrchestrator.self) var orchestrator
    @Environment(TunnelManager.self) var tunnel
    @Environment(CloudProviderHealth.self) var cloudHealth
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
                        ProviderRow(label: "OpenRouter", placeholder: "sk-or-... (free, no card)", providerId: "openrouter", key: $settings.freeRouterKey)
                        divider
                        ProviderRow(label: "Groq",        placeholder: "gsk_...",                   providerId: "groq",       key: $settings.groqKey)
                        divider
                        ProviderRow(label: "Together",    placeholder: "tgp_...",                   providerId: "together",   key: $settings.togetherKey)
                        divider
                        ProviderRow(label: "DeepSeek",    placeholder: "sk-...",                    providerId: "deepseek",   key: $settings.deepseekKey)
                        divider
                        ProviderRow(label: "Mistral",     placeholder: "U1kEM...",                  providerId: "mistral",    key: $settings.mistralKey)
                        divider
                        ProviderRow(label: "Perplexity",  placeholder: "pplx-...",                  providerId: "perplexity", key: $settings.perplexityKey)
                        divider
                        ProviderRow(label: "Cohere",      placeholder: "CO_KEY_...",                providerId: "cohere",     key: $settings.cohereKey)
                        divider
                        ProviderRow(label: "Fireworks",   placeholder: "fw_...",                    providerId: "fireworks",  key: $settings.fireworksKey)
                        divider
                        ProviderRow(label: "Hyperbolic",  placeholder: "eyJ...",                    providerId: "hyperbolic", key: $settings.hyperbolicKey)
                        divider
                        ProviderRow(label: "Sambanova",   placeholder: "ab1...",                    providerId: "sambanova",  key: $settings.sambanovaKey)

                        HStack(spacing: 10) {
                            Circle().fill(Color.green).frame(width: 6, height: 6)
                            Text("Connected").font(DesignTokens.Font.caption2).foregroundColor(DesignTokens.Color.secondaryText)
                            Circle().fill(Color.yellow).frame(width: 6, height: 6)
                            Text("Low quota / rate limited").font(DesignTokens.Font.caption2).foregroundColor(DesignTokens.Color.secondaryText)
                            Circle().fill(Color.red).frame(width: 6, height: 6)
                            Text("Exhausted / invalid key").font(DesignTokens.Font.caption2).foregroundColor(DesignTokens.Color.secondaryText)
                        }
                        .padding(.top, 2)

                        Text("When you send \"model=free\", PaglaMLX tries each configured free provider in random order until one responds. Add keys for any providers you want in the pool — leave the rest empty.")
                            .font(DesignTokens.Font.caption)
                            .foregroundColor(DesignTokens.Color.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } header: {
                    HStack {
                        Text("Free Router — Multi-Provider Pool")
                            .font(DesignTokens.Font.subheadline)
                        Spacer()
                        if cloudHealth.isRunning {
                            ProgressView().controlSize(.small).scaleEffect(0.7)
                        } else {
                            Button {
                                Task { await cloudHealth.checkAll() }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .help("Check all provider connections")
                        }
                    }
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
                        .font(DesignTokens.Font.label)
                        .foregroundColor(DesignTokens.Color.secondaryText)
                } header: {
                    Text("Direct API Keys")
                        .font(DesignTokens.Font.subheadline)
                }

                Section {
                    VStack(spacing: 1) {
                        ProviderRow(label: "OpenRouter", placeholder: "sk-or-...", key: $settings.openrouterKey)
                    }
                    .padding(.vertical, 4)

                    Text("Prefix with \"openrouter/\" to pick a specific model. For automatic cheapest routing, use the Free Router key above with \"model=free\".")
                        .font(DesignTokens.Font.label)
                        .foregroundColor(DesignTokens.Color.secondaryText)
                } header: {
                    Text("Advanced: OpenRouter (Direct)")
                        .font(DesignTokens.Font.subheadline)
                }

                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 10) {
                            keyDot(true)
                            Text("Key set").font(DesignTokens.Font.label)
                            keyDot(false)
                            Text("Key empty").font(DesignTokens.Font.label)
                        }
                        .foregroundColor(DesignTokens.Color.secondaryText)

                        Text("model=\"auto\" uses heuristic engine: VLM for images → context-fit scoring → keyword intent (code/math/reasoning) → best local model. model=\"free\" tries all configured free providers in failover chain (randomized, health-weighted).")
                            .font(DesignTokens.Font.label)
                            .foregroundColor(DesignTokens.Color.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } header: {
                    Text("Routing Behaviour")
                        .font(DesignTokens.Font.subheadline)
                }
            }
            }
            .font(DesignTokens.Font.label)
            .padding(20)
            .tabItem {
                Label("Cloud", systemImage: "cloud.fill")
            }
            .tag(6)
            .task { await cloudHealth.checkAll() }
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
            ApiDetailsTab()
                .padding(20)
                .tabItem {
                    Label("API Details", systemImage: "doc.text.magnifyingglass")
                }
                .tag(8)
            
        }
        .frame(minWidth: 600, maxWidth: 680, minHeight: 480, idealHeight: 560)
    }
}

// MARK: - API Details Tab

private struct ApiDetailsTab: View {
    @Environment(SettingsManager.self) var settings
    @Environment(ModelOrchestrator.self) var orchestrator

    var body: some View {
        let runningModels: [(name: String, port: Int, modelType: String)] = orchestrator.instances.compactMap { name, inst in
            inst.isRunning ? (name, inst.port, inst.model.modelType) : nil
        }
        ApiReferenceView(
            host: settings.host,
            port: settings.port,
            apiKey: settings.apiKey,
            allowedOrigins: settings.allowedOrigins,
            freeRouterEnabled: settings.freeRouterEnabled,
            temp: settings.temp,
            topP: settings.topP,
            topK: settings.topK,
            minP: settings.minP,
            maxTokens: settings.maxTokens,
            logLevel: settings.logLevel.rawValue,
            trustRemoteCode: settings.trustRemoteCode,
            chatTemplateArgs: settings.chatTemplateArgs,
            gatewayRunning: RoutingGateway.shared.isRunning,
            runningModels: runningModels
        )
    }
}

// MARK: - Design System Helpers

private struct ProviderRow: View {
    let label: String
    let placeholder: String
    var providerId: String? = nil
    @Binding var key: String

    @Environment(CloudProviderHealth.self) private var cloudHealth

    var body: some View {
        HStack(spacing: 6) {
            if let pid = providerId {
                healthDot(for: pid)
                    .frame(width: 6)
            } else {
                keyDot(!key.isEmpty)
                    .frame(width: 6)
            }

            Text(label + ":")
                .font(DesignTokens.Font.label)
                .foregroundStyle(.primary)
                .frame(width: 82, alignment: .trailing)

            SecureField(placeholder, text: $key)
                .font(DesignTokens.Font.label)
                .textFieldStyle(.plain)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(DesignTokens.Color.border, lineWidth: 1)
                )
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 3)
    }

    private func healthDot(for id: String) -> some View {
        let health = cloudHealth.statuses[id]?.health ?? .notConfigured
        return Circle()
            .fill(health.dotColor)
            .frame(width: 6, height: 6)
    }
}

private var divider: some View {
    Divider().overlay(DesignTokens.Color.border)
}

private func keyDot(_ filled: Bool) -> some View {
    Circle()
        .fill(filled ? DesignTokens.Color.dotFilled : DesignTokens.Color.dotEmpty)
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
