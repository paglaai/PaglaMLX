import SwiftUI

struct ContentView: View {
    @Environment(ModelOrchestrator.self) var orchestrator
    @Environment(SettingsManager.self) var settings
    @Environment(RemoteAccessManager.self) var remoteAccess
    @State private var showingQRCode = false
    @State private var logSearch = ""
    @State private var logLevelFilters: Set<LogEntry.Level> = Set(LogEntry.Level.allCases)
    @State private var showingGatewayErrors = false
    @State private var benchmark = BenchmarkManager.shared

    var body: some View {
        @Bindable var orchestrator = orchestrator
        @Bindable var settings = settings
        @Bindable var remoteAccess = remoteAccess
        @Bindable var benchmark = benchmark
        NavigationSplitView {
            List(selection: $orchestrator.selectedModel) {
                if orchestrator.models.isEmpty {
                    if #available(macOS 14.0, *) {
                        ContentUnavailableView("No Models Found", systemImage: "magnifyingglass", description: Text("Please ensure your Models Directory is configured and contains valid model files."))
                    } else {
                        Text("No models found")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                } else {
                    ForEach(orchestrator.models) { model in
                        NavigationLink(value: model) {
                            HStack {
                                Image(systemName: model.typeIcon)
                                    .foregroundColor(model.modelType == "VLM" ? .blue : .primary)

                                VStack(alignment: .leading) {
                                    Text(model.name).font(.headline).lineLimit(1)
                                    Text("\(model.sizeFormatted) • \(model.contextLength) ctx")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if let inst = orchestrator.instances[model.name] {
                                    if inst.isRunning {
                                        HStack(spacing: 3) {
                                            Circle()
                                                .fill(inst.healthStatus.color)
                                                .frame(width: 7, height: 7)
                                            if inst.healthStatus != .healthy {
                                                Text(inst.healthStatus.rawValue.prefix(1).uppercased())
                                                    .font(DesignTokens.Font.monospacedSmall)
                                                    .foregroundColor(inst.healthStatus.color)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Models")
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { orchestrator.scanModels() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh Models")
                    .help("Rescan Models Directory")
                }
                ToolbarItem(placement: .automatic) {
                    Button(action: { showingApiReference = true }) {
                        Image(systemName: "doc.text.magnifyingglass")
                    }
                    .accessibilityLabel("API Reference")
                    .help("Show API reference & server details")
                }
            }
            .sheet(isPresented: $showingApiReference) {
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
                .frame(width: 700, height: 600)
            }

        } detail: {
            if let selectedModel = orchestrator.selectedModel {
                detailView(selectedModel)
            } else {
                noSelectionPanel
            }
        }
    }

    // MARK: - No Selection Panel

    @State private var showingApiReference = false
    @State private var noSelectionTab = 0

    private var noSelectionPanel: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $noSelectionTab) {
                Text("Activity Dashboard").tag(0)
                Text("API Reference").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            if noSelectionTab == 0 {
                ActivityDashboardView()
                    .environment(orchestrator)
                    .environment(settings)
            } else {
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
    }

    // MARK: - Detail

    private func detailView(_ selectedModel: MLXModel) -> some View {
        let isRunning = orchestrator.instances[selectedModel.name]?.isRunning == true
        let inst = orchestrator.instances[selectedModel.name]
        let logs = inst?.logs ?? []
        let filteredLogs = filtered(logs)
        let healthStatus = inst?.healthStatus ?? .unknown

        return VStack(spacing: 0) {
            headerBar(selectedModel, isRunning: isRunning, healthStatus: healthStatus)

            Divider()

            logControls
                .padding(.horizontal)
                .padding(.vertical, 6)

            logConsole(filteredLogs)

            gatewayErrorsPanel

            benchmarkPanel(selectedModel, isRunning: isRunning)

            errorFooter
        }
        .navigationTitle(selectedModel.name)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: exportLogs) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Export logs")
                .help("Export logs to file")
                .disabled(logs.isEmpty)

                Button(action: { orchestrator.clearLogs() }) {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Clear Console logs")
                .help("Clear Console logs")
                .disabled(logs.isEmpty)
            }
        }
    }

    // MARK: - Header

    private func headerBar(_ model: MLXModel, isRunning: Bool, healthStatus: ModelInstance.HealthStatus) -> some View {
        HStack {
            Circle()
                .fill(isRunning ? healthStatus.color : DesignTokens.Color.error)
                .frame(width: 10, height: 10)

            Text(isRunning ? healthStatus.rawValue.capitalized : "Stopped")
                .font(.headline)

            Spacer()

            if isRunning {
                let url = remoteAccess.bestRemoteURL ?? orchestrator.instances[model.name]?.serverURL ?? ""
                Text(url)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)

                Button(action: { showingQRCode = true }) {
                    Image(systemName: "qrcode")
                }
                .accessibilityLabel("Show QR Code")
                .help("Show Termux QR Code")
                .popover(isPresented: $showingQRCode) {
                    QRCodeView(url: url)
                }
            }

            if isRunning, let inst = orchestrator.instances[model.name] {
                Button(action: { Task { await inst.performHealthCheck() } }) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh health status")
                .buttonStyle(.plain)

                if !inst.warmPoolActive {
                    Button(action: { inst.warm() }) {
                        Image(systemName: "flame")
                    }
                    .help("Pre-heat model (warm pool)")
                    .buttonStyle(.plain)
                } else {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                        .help("Warm pool active")
                }
            }

            Button(action: { orchestrator.toggleSelected() }) {
                Text(isRunning ? "Stop" : "Start")
                    .frame(width: 60)
            }
            .buttonStyle(.borderedProminent)
            .tint(isRunning ? DesignTokens.Color.destructive : DesignTokens.Color.success)
        }
        .padding()
        .background(.background)
    }

    // MARK: - Log Controls

    private var logControls: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search logs…", text: $logSearch)
                    .textFieldStyle(.plain)
                    .font(.system(.caption, design: .monospaced))
            }
            .padding(6)
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(6)

            HStack(spacing: 4) {
                ForEach(LogEntry.Level.allCases, id: \.self) { level in
                    Button(action: {
                        if logLevelFilters.contains(level) {
                            logLevelFilters.remove(level)
                        } else {
                            logLevelFilters.insert(level)
                        }
                    }) {
                        Text(level.label)
                            .font(DesignTokens.Font.monospacedSmall)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(logLevelFilters.contains(level) ? level.color.opacity(0.2) : Color.clear)
                            .foregroundColor(logLevelFilters.contains(level) ? level.color : .secondary)
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(logLevelFilters.contains(level) ? level.color : Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                if let inst = orchestrator.instances[orchestrator.selectedModel?.name ?? ""] {
                    Text("\(filtered(inst.logs).count)/\(inst.logs.count)")
                        .font(DesignTokens.Font.monospacedSmall)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Log Console

    private func logConsole(_ logs: [LogEntry]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(logs) { log in
                        Text(log.text)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(log.color)
                            .id(log.id)
                            .textSelection(.enabled)
                    }
                }
                .padding()
            }
            .background(Color(nsColor: .textBackgroundColor))
            .onChange(of: logs.count) { _, _ in
                if let last = logs.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Gateway Errors

    @ViewBuilder
    private var gatewayErrorsPanel: some View {
        let errors = RoutingGateway.shared.recentErrors
        if !errors.isEmpty {
            VStack(spacing: 0) {
                Button(action: { showingGatewayErrors.toggle() }) {
                    HStack {
                        Label("Gateway Errors (\(errors.count))", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Spacer()
                        Image(systemName: showingGatewayErrors ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(DesignTokens.Color.warning.opacity(0.08))
                }
                .buttonStyle(.plain)

                if showingGatewayErrors {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(errors.prefix(20), id: \.self) { err in
                                Text(err)
                                    .font(DesignTokens.Font.monospacedSmall)
                                    .foregroundColor(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 100)
                }
            }
        }
    }

    // MARK: - Benchmark

    private func benchmarkPanel(_ model: MLXModel, isRunning: Bool) -> some View {
        VStack(spacing: 4) {
            Divider()
            HStack {
                Label("Benchmark", systemImage: "gauge")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if benchmark.isRunning {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                    Text(benchmark.currentProgress)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let last = benchmark.results.first(where: { $0.modelName == model.name }) {
                    Text("\(String(format: "%.1f", last.tokensPerSecond)) tok/s")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.0f", last.latencyMs)) ms")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Button("Run") {
                    guard let inst = orchestrator.instances[model.name], inst.isRunning else { return }
                    benchmark.runBenchmark(model: model, port: inst.port, apiKey: settings.apiKey)
                }
                .disabled(!isRunning || benchmark.isRunning)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Error Footer

    @ViewBuilder
    private var errorFooter: some View {
        if let err = orchestrator.errorMessage {
            HStack {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .symbolRenderingMode(.hierarchical)
                Spacer()
            }
            .padding(8)
            .background(DesignTokens.Color.warning.opacity(0.1))
        }
    }

    // MARK: - Helpers

    private func filtered(_ logs: [LogEntry]) -> [LogEntry] {
        var result = logs
        if !logLevelFilters.isEmpty && logLevelFilters.count < LogEntry.Level.allCases.count {
            result = result.filter { logLevelFilters.contains($0.level) }
        }
        if !logSearch.isEmpty {
            result = result.filter { $0.text.localizedCaseInsensitiveContains(logSearch) }
        }
        return result
    }

    private func exportLogs() {
        guard let sel = orchestrator.selectedModel,
              let inst = orchestrator.instances[sel.name] else { return }

        let logText = inst.logs.map { "[\($0.level.label)] \($0.text)" }.joined(separator: "\n")
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(sel.name)-logs.txt"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? logText.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
